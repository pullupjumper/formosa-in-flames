const isDev = import.meta.env.DEV;

// Dev 模式下使用完整路徑，build 後使用簡短路徑
const getPageUrl = (page: string) => {
  return isDev ? `/src/pages/${page}/index.html` : `/${page}.html`;
};

function App() {
  return (
    <div className="flex h-screen items-center justify-center">
      <div className="rounded-sm border border-dark-border bg-dark-panel p-8 text-center">
        <h1 className="mb-4 text-2xl font-semibold text-text-primary">CMO UI Components</h1>
        <p className="text-text-secondary">React + TypeScript + Tailwind CSS</p>
        <div className="mt-6 flex gap-4">
          <a
            href={getPageUrl('setup-menu')}
            className="rounded bg-accent-blue px-4 py-2 text-sm text-white hover:bg-accent-blue-hover"
          >
            Setup Menu
          </a>
          <a
            href={getPageUrl('emcon-setting')}
            className="rounded bg-accent-blue px-4 py-2 text-sm text-white hover:bg-accent-blue-hover"
          >
            EMCON Setting
          </a>
          <a
            href={getPageUrl('unit-status')}
            className="rounded bg-accent-blue px-4 py-2 text-sm text-white hover:bg-accent-blue-hover"
          >
            Unit Status
          </a>
        </div>
      </div>
    </div>
  );
}

export default App;
