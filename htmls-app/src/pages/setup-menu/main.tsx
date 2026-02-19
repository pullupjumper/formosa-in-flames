import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '../../index.css';
import SetupMenuPage from './SetupMenuPage.tsx';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <SetupMenuPage />
  </StrictMode>
);
