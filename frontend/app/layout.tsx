import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Pigsty App DB — тест подключения',
  description: 'Тестовый фронтенд для проверки подключения к БД app на Pigsty',
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
