import { Component, signal } from '@angular/core';

@Component({
  selector: 'app-root',
  templateUrl: './app.html',
})
export class App {
  message = signal('Loading…');

  constructor() {
    fetch('/api/hello')
      .then(r => r.json())
      .then(d => this.message.set(d.message))
      .catch(() => this.message.set('Could not reach the API'));
  }
}
