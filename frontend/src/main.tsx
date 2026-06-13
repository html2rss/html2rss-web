import { render } from 'preact';
import { App } from './components/App';
import './styles/main.css';

function Root() {
  return <App />;
}

render(<Root />, document.querySelector('#app')!);
