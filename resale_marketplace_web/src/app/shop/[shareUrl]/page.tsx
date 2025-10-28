import { notFound } from 'next/navigation';
import { getShopByShareUrl } from '@/lib/services/shopService';
import ShopPageClient from './ShopPageClient';

interface PageProps {
  params: Promise<{
    shareUrl: string;
  }>;
}

export default async function ShopPage({ params }: PageProps) {
  const { shareUrl } = await params;

  // Fetch real data from Supabase
  const shopData = await getShopByShareUrl(shareUrl);

  // Show 404 if shop not found
  if (!shopData) {
    notFound();
  }

  const { shop, ownProducts, resaleProducts } = shopData;

  return (
    <ShopPageClient
      shop={shop}
      ownProducts={ownProducts}
      resaleProducts={resaleProducts}
      shareUrl={shareUrl}
    />
  );
}
