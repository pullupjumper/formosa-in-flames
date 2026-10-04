import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '../../index.css';
import ControlPanelPage from './ControlPanelPage.tsx';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ControlPanelPage />
  </StrictMode>
);
