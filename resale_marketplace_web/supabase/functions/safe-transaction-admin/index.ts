import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    const { action, safeTransactionId, adminNotes, trackingNumber, courier } = await req.json()

    // Verify admin role
    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) {
      throw new Error('Unauthorized')
    }

    const { data: userData, error: userError } = await supabaseClient
      .from('users')
      .select('role')
      .eq('id', user.id)
      .single()

    if (userError || userData?.role !== '관리자') {
      throw new Error('Admin access required')
    }

    let result;

    switch (action) {
      case 'confirm_deposit':
        result = await confirmDeposit(supabaseClient, safeTransactionId, adminNotes)
        break
      case 'confirm_shipping':
        result = await confirmShipping(supabaseClient, safeTransactionId, trackingNumber, courier)
        break
      case 'process_settlement':
        result = await processSettlement(supabaseClient, safeTransactionId, adminNotes)
        break
      case 'update_notes':
        result = await updateNotes(supabaseClient, safeTransactionId, adminNotes)
        break
      case 'get_stats':
        result = await getSafeTransactionStats(supabaseClient)
        break
      case 'get_list':
        result = await getSafeTransactionList(supabaseClient, req.url)
        break
      default:
        throw new Error('Invalid action')
    }

    return new Response(
      JSON.stringify(result),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
})

async function confirmDeposit(supabaseClient: any, safeTransactionId: string, adminNotes?: string) {
  // Update safe transaction
  const { error: updateError } = await supabaseClient
    .from('safe_transactions')
    .update({
      deposit_confirmed: true,
      deposit_confirmed_at: new Date().toISOString(),
      admin_notes: adminNotes || '입금 확인 완료',
    })
    .eq('id', safeTransactionId)

  if (updateError) throw updateError

  // Get transaction details for SMS
  const { data: safeTransaction, error: fetchError } = await supabaseClient
    .from('safe_transactions')
    .select(`
      *,
      transactions!transaction_id (
        *,
        products!product_id (title),
        buyer:users!buyer_id (name, phone),
        seller:users!seller_id (name, phone),
        reseller:users!reseller_id (name, phone)
      )
    `)
    .eq('id', safeTransactionId)
    .single()

  if (fetchError) throw fetchError

  // Send SMS notifications
  const transaction = safeTransaction.transactions
  const product = transaction.products
  const seller = transaction.seller
  const reseller = transaction.reseller

  // SMS to seller
  if (seller?.phone) {
    await sendSMS(supabaseClient, {
      phone_number: seller.phone,
      message_type: '입금확인',
      message_content: `입금이 확인되었습니다.\n상품: ${product?.title}\n금액: ${formatCurrency(safeTransaction.deposit_amount)}\n상품을 발송해주세요.`
    })
  }

  // SMS to reseller if exists
  if (reseller?.phone) {
    await sendSMS(supabaseClient, {
      phone_number: reseller.phone,
      message_type: '입금확인',
      message_content: `입금이 확인되었습니다.\n상품: ${product?.title}\n수수료 정산이 예정되어 있습니다.`
    })
  }

  return { success: true, message: '입금이 확인되었습니다.' }
}

async function confirmShipping(supabaseClient: any, safeTransactionId: string, trackingNumber?: string, courier?: string) {
  let notes = '배송 시작'
  if (trackingNumber) notes += ` - 운송장: ${trackingNumber}`
  if (courier) notes += ` (${courier})`

  // Update safe transaction
  const { error: updateError } = await supabaseClient
    .from('safe_transactions')
    .update({
      shipping_confirmed: true,
      shipping_confirmed_at: new Date().toISOString(),
      admin_notes: notes,
    })
    .eq('id', safeTransactionId)

  if (updateError) throw updateError

  // Get transaction details for SMS
  const { data: safeTransaction, error: fetchError } = await supabaseClient
    .from('safe_transactions')
    .select(`
      *,
      transactions!transaction_id (
        *,
        products!product_id (title),
        buyer:users!buyer_id (name, phone)
      )
    `)
    .eq('id', safeTransactionId)
    .single()

  if (fetchError) throw fetchError

  // SMS to buyer
  const transaction = safeTransaction.transactions
  const product = transaction.products
  const buyer = transaction.buyer

  if (buyer?.phone) {
    let message = `상품이 발송되었습니다.\n상품: ${product?.title}\n`
    if (trackingNumber) message += `운송장번호: ${trackingNumber}\n`
    if (courier) message += `택배사: ${courier}\n`
    message += '상품 수령 후 완료 버튼을 눌러주세요.'

    await sendSMS(supabaseClient, {
      phone_number: buyer.phone,
      message_type: '배송시작',
      message_content: message
    })
  }

  return { success: true, message: '배송이 확인되었습니다.' }
}

async function processSettlement(supabaseClient: any, safeTransactionId: string, adminNotes?: string) {
  // Update safe transaction
  const { error: updateError } = await supabaseClient
    .from('safe_transactions')
    .update({
      settlement_status: '정산완료',
      admin_notes: adminNotes || '정산 처리 완료',
    })
    .eq('id', safeTransactionId)

  if (updateError) throw updateError

  // Update transaction status to completed
  const { data: safeTransaction } = await supabaseClient
    .from('safe_transactions')
    .select('transaction_id')
    .eq('id', safeTransactionId)
    .single()

  if (safeTransaction) {
    await supabaseClient
      .from('transactions')
      .update({
        status: '거래완료',
        completed_at: new Date().toISOString(),
      })
      .eq('id', safeTransaction.transaction_id)
  }

  return { success: true, message: '정산이 완료되었습니다.' }
}

async function updateNotes(supabaseClient: any, safeTransactionId: string, adminNotes: string) {
  const { error } = await supabaseClient
    .from('safe_transactions')
    .update({ admin_notes: adminNotes })
    .eq('id', safeTransactionId)

  if (error) throw error

  return { success: true, message: '메모가 업데이트되었습니다.' }
}

async function getSafeTransactionStats(supabaseClient: any) {
  const { count: totalCount } = await supabaseClient
    .from('safe_transactions')
    .select('*', { count: 'exact', head: true })

  const { count: waitingDepositCount } = await supabaseClient
    .from('safe_transactions')
    .select('*', { count: 'exact', head: true })
    .eq('deposit_confirmed', false)

  const { count: waitingShippingCount } = await supabaseClient
    .from('safe_transactions')
    .select('*', { count: 'exact', head: true })
    .eq('deposit_confirmed', true)
    .eq('shipping_confirmed', false)

  const { count: shippingCount } = await supabaseClient
    .from('safe_transactions')
    .select('*', { count: 'exact', head: true })
    .eq('shipping_confirmed', true)
    .eq('delivery_confirmed', false)

  const { count: waitingSettlementCount } = await supabaseClient
    .from('safe_transactions')
    .select('*', { count: 'exact', head: true })
    .eq('settlement_status', '대기중')

  const { count: completedCount } = await supabaseClient
    .from('safe_transactions')
    .select('*', { count: 'exact', head: true })
    .eq('settlement_status', '정산완료')

  return {
    totalCount: totalCount || 0,
    waitingDepositCount: waitingDepositCount || 0,
    waitingShippingCount: waitingShippingCount || 0,
    shippingCount: shippingCount || 0,
    waitingSettlementCount: waitingSettlementCount || 0,
    completedCount: completedCount || 0,
  }
}

async function getSafeTransactionList(supabaseClient: any, url: string) {
  const urlParams = new URL(url).searchParams
  const status = urlParams.get('status')
  const limit = parseInt(urlParams.get('limit') || '50')
  const offset = parseInt(urlParams.get('offset') || '0')

  let query = supabaseClient
    .from('safe_transactions')
    .select(`
      *,
      transactions!transaction_id (
        *,
        products!product_id (title),
        buyer:users!buyer_id (name, phone),
        seller:users!seller_id (name, phone),
        reseller:users!reseller_id (name, phone)
      )
    `)

  if (status) {
    query = query.eq('settlement_status', status)
  }

  const { data, error } = await query
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1)

  if (error) throw error

  return { data: data || [] }
}

async function sendSMS(supabaseClient: any, smsData: any) {
  // Log SMS in database
  await supabaseClient
    .from('sms_logs')
    .insert({
      phone_number: smsData.phone_number,
      message_type: smsData.message_type,
      message_content: smsData.message_content,
      is_sent: true,
      sent_at: new Date().toISOString(),
    })

  // In production, integrate with actual SMS service
  console.log('SMS sent:', smsData)
}

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('ko-KR', {
    style: 'currency',
    currency: 'KRW',
  }).format(amount)
}