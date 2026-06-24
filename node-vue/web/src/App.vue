<script setup>
import { ref, onMounted } from 'vue'

const message = ref('')
const loading = ref(true)
const error = ref(false)

// Re-fetch the API message without reloading the page (the SPA model).
function reload() {
  loading.value = true
  error.value = false
  fetch('/api/hello')
    .then((res) => {
      if (!res.ok) throw new Error(`Request failed: ${res.status}`)
      return res.json()
    })
    .then((data) => {
      message.value = data.message
      loading.value = false
    })
    .catch(() => {
      error.value = true
      loading.value = false
    })
}

onMounted(reload)
</script>

<template>
  <main>
    <!-- This text is rendered by Vue. Edit it, save, and the browser live-reloads. -->
    <h1>CoderFlow reference app</h1>
    <p class="framework">Front end: <strong>Vue</strong></p>

    <p class="label">Message from the API</p>
    <p class="api-message">
      <span v-if="loading">Loading…</span>
      <span v-else-if="error">Could not reach the API</span>
      <span v-else>{{ message }}</span>
    </p>

    <button @click="reload" :disabled="loading">Reload from API</button>
  </main>
</template>

<style>
/* Global styles for the CoderFlow reference client. */
* { box-sizing: border-box; }

body {
  margin: 0;
  min-height: 100vh;
  display: grid;
  place-items: center;
  font-family: system-ui, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  background: #f1f5f9;
  color: #0f172a;
}

main {
  text-align: center;
  padding: 2.5rem 3rem;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  box-shadow: 0 12px 32px rgba(15, 23, 42, 0.08);
  max-width: 32rem;
}

h1 { margin: 0 0 0.25rem; font-size: 1.5rem; }

.framework { margin: 0 0 1.75rem; color: #64748b; }

.label {
  margin: 0 0 0.35rem;
  color: #94a3b8;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.api-message {
  margin: 0 0 1.75rem;
  font-size: 1.4rem;
  font-weight: 600;
  color: #2563eb;
  min-height: 1.5em;
}

button {
  font: inherit;
  font-weight: 600;
  padding: 0.6rem 1.4rem;
  border: 0;
  border-radius: 9px;
  background: #2563eb;
  color: #ffffff;
  cursor: pointer;
  transition: background 0.15s ease;
}

button:hover:not(:disabled) { background: #1d4ed8; }
button:disabled { opacity: 0.55; cursor: default; }
</style>
