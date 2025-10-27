import Link from 'next/link';

export default function ShopNotFound() {
  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center px-4">
      <div className="max-w-md w-full text-center">
        <div className="mb-8">
          <svg
            className="mx-auto h-24 w-24 text-gray-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"
            />
          </svg>
        </div>

        <h1 className="text-4xl font-bold text-gray-900 mb-4">샵을 찾을 수 없습니다</h1>

        <p className="text-gray-600 mb-8">
          요청하신 샵이 존재하지 않거나 삭제되었습니다.
          <br />
          URL을 확인하시고 다시 시도해주세요.
        </p>

        <div className="space-y-3">
          <Link
            href="/"
            className="block w-full bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-colors font-medium"
          >
            홈으로 돌아가기
          </Link>

          <button
            onClick={() => window.history.back()}
            className="block w-full bg-white text-gray-700 border border-gray-300 px-6 py-3 rounded-lg hover:bg-gray-50 transition-colors font-medium"
          >
            이전 페이지로
          </button>
        </div>

        <div className="mt-8 text-sm text-gray-500">
          <p>문제가 계속되면 고객센터로 문의해주세요.</p>
        </div>
      </div>
    </div>
  );
}
