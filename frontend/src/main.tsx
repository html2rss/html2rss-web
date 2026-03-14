import { render } from 'preact';
import { App } from './components/App';
import { Footer } from './components/Footer';
import './styles/main.css';

function Root() {
  return (
    <div class="page-shell">
      <main class="page-main">
        <App />
      </main>
      <Footer />
    </div>
  );
}

render(<Root />, document.getElementById('app')!);
