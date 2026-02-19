import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '../../index.css';
import EmconSettingPage from './EmconSettingPage.tsx';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <EmconSettingPage />
  </StrictMode>
);
