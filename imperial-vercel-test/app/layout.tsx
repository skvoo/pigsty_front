import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Imperial test — imperialdb + MinIO',
  description: 'Тест подключения к БД imperialdb и файлам MinIO на Vercel',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ru">
      <body>{children}</body>
    </html>
  );
}
