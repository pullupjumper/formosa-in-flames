import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '../../index.css';
import UnitStatusPage from './UnitStatusPage.tsx';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <UnitStatusPage />
  </StrictMode>
);
