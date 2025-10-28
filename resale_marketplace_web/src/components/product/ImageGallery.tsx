'use client';

import React from 'react';
import Image from 'next/image';
import { ProductStatus } from '@/types';

interface ImageGalleryProps {
  images: string[];
  title: string;
  selectedImage: number;
  onSelectImage: (index: number) => void;
  status: ProductStatus;
}

export default function ImageGallery({
  images,
  title,
  selectedImage,
  onSelectImage,
  status,
}: ImageGalleryProps) {
  return (
    <div className="bg-white rounded-xl overflow-hidden">
      {/* Main Image */}
      <div className="relative aspect-square bg-gray-100">
        {images[selectedImage] ? (
          <Image
            src={images[selectedImage]}
            alt={title}
            fill
            className="object-cover"
            priority
            sizes="(max-width: 1024px) 100vw, 50vw"
          />
        ) : (
          <div className="flex items-center justify-center h-full">
            <svg className="w-20 h-20 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
          </div>
        )}

        {/* Status Badge */}
        {status === ProductStatus.SOLD && (
          <div className="absolute top-4 left-4 bg-gray-900 bg-opacity-75 text-white px-4 py-2 rounded-lg text-lg font-semibold">
            판매완료
          </div>
        )}
      </div>

      {/* Thumbnail Images */}
      <div className="p-4">
        <div className="grid grid-cols-4 gap-2">
          {images.map((image, index) => (
            <button
              key={index}
              onClick={() => onSelectImage(index)}
              className={`relative aspect-square rounded-lg overflow-hidden border-2 transition-all ${
                selectedImage === index ? 'border-blue-500' : 'border-gray-200'
              }`}
            >
              <Image
                src={image}
                alt={`${title} ${index + 1}`}
                fill
                className="object-cover"
                loading="lazy"
                sizes="(max-width: 1024px) 25vw, 12vw"
              />
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
