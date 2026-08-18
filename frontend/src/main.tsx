import { render } from 'preact';
import { App } from './components/App';
import './styles/main.css';

function Root() {
  return <App />;
}

const root = document.querySelector('#app');
if (!root) {
  throw new Error('Missing #app mount node');
}

render(<Root />, root);
