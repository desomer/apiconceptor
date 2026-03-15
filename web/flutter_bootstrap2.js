{{flutter_js}}
{{flutter_build_config}}

const loading = document.createElement('div');
document.body.appendChild(loading);
loading.textContent = "Loading Entrypoint...";

const v = '{{flutter_service_worker_version}}';
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: v,
  },
  onEntrypointLoaded: async function (engineInitializer) {
    loading.textContent = "Initializing engine...";
    const appRunner = await engineInitializer.initializeEngine({
      useColorEmoji: true, // Add emoji color setting
    });
    loading.textContent = "Running app...";
    await appRunner.runApp();
  }
});