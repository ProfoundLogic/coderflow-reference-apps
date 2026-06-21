<script setup>
import { ref, onMounted } from 'vue'

const message = ref('')
const error = ref('')
const loading = ref(true)

onMounted(async () => {
  try {
    const response = await fetch('/api/hello')
    if (!response.ok) {
      throw new Error(`Request failed with status ${response.status}`)
    }
    const data = await response.json()
    message.value = data.message
  } catch (err) {
    error.value = 'Could not reach the API'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <main>
    <p v-if="loading">Loading…</p>
    <p v-else-if="error">{{ error }}</p>
    <h1 v-else>{{ message }}</h1>
    <p class="subtitle">Vue + Vite client</p>
  </main>
</template>
