export default function Home() {
  return (
    <main style={{ padding: '2rem', maxWidth: 600, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.25rem' }}>Imperial test (Vercel)</h1>
      <p style={{ color: 'var(--muted)', marginTop: '0.5rem' }}>
        Тест подключения к imperialdb и отображения файлов из MinIO.
      </p>
      <p style={{ marginTop: '1.5rem' }}>
        <a href="/test-imperial">Открыть тест → /test-imperial</a>
      </p>
    </main>
  );
}
