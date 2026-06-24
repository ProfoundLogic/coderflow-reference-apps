import { useEffect, useState } from 'react';

export default function App() {
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  // Re-fetch the API message without reloading the page (the SPA model).
  function reload() {
    setLoading(true);
    setError(false);
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
  }

  useEffect(() => {
    reload();
  }, []);

  return (
    <main>
      {/* This text is rendered by React. Edit it, save, and the browser live-reloads. */}
      <h1>CoderFlow reference app</h1>
      <p className="framework">Front end: <strong>React</strong></p>

      <p className="label">Message from the API</p>
      <p className="api-message">
        {loading ? 'Loading…' : error ? 'Could not reach the API' : message}
      </p>

      <button onClick={reload} disabled={loading}>Reload from API</button>
    </main>
  );
}
