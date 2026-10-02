import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '../../index.css';
import AddUnitsMenuPage from './AddUnitsMenuPage.tsx';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AddUnitsMenuPage />
  </StrictMode>
);
