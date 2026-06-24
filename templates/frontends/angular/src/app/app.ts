import { Component, signal } from '@angular/core';

@Component({
  selector: 'app-root',
  templateUrl: './app.html',
})
export class App {
  message = signal('');
  loading = signal(true);
  error = signal(false);

  constructor() {
    this.reload();
  }

  // Re-fetch the API message without reloading the page (the SPA model).
  reload(): void {
    this.loading.set(true);
    this.error.set(false);
    fetch('/api/hello')
      .then(res => {
        if (!res.ok) throw new Error(`Request failed: ${res.status}`);
        return res.json();
      })
      .then(data => {
        this.message.set(data.message);
        this.loading.set(false);
      })
      .catch(() => {
        this.error.set(true);
        this.loading.set(false);
      });
  }
}
