import { useEffect, useState } from 'react';

export default function App() {
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    fetch('/api/hello')
      .then((res) => {
        if (!res.ok) throw new Error(`Request failed: ${res.status}`);
        return res.json();
      })
      .then((data) => {
        setMessage(data.message);
        setLoading(false);
      })
      .catch(() => {
        setError(true);
        setLoading(false);
      });
  }, []);

  return (
    <main>
      {loading && <p>Loading…</p>}
      {error && <h1>Could not reach the API</h1>}
      {!loading && !error && <h1>{message}</h1>}
      <p>React + Vite client</p>
    </main>
  );
}
