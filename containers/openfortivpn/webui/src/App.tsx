import { createSignal, onCleanup, createResource } from "solid-js";

const API_BASE = "";

interface VPNStatus {
  state: string;
  interface?: string;
  ip?: string;
  uptime_seconds?: number;
  last_error?: string;
  saml_url?: string;
}

async function fetchStatus(): Promise<VPNStatus> {
  const res = await fetch(`${API_BASE}/status`);
  return res.json();
}

function formatUptime(seconds?: number): string {
  if (!seconds) return "-";
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}m ${s}s`;
}

function StatusDot(props: { state: string }) {
  const colorMap: Record<string, string> = {
    connected: "bg-green-500",
    connecting: "bg-yellow-500",
    error: "bg-red-500",
    disconnected: "bg-gray-500",
  };
  return (
    <div class={`w-3.5 h-3.5 rounded-full ${colorMap[props.state] || colorMap.disconnected}`} />
  );
}

function Card(props: { children: any }) {
  return (
    <div class="bg-[#161b22] border border-[#30363d] rounded-lg p-5 my-4">
      {props.children}
    </div>
  );
}

export default function App() {
  const [status, { refetch }] = createResource(fetchStatus);
  const [toast, setToast] = createSignal<{ msg: string; type: string } | null>(null);
  const [loading, setLoading] = createSignal(false);

  const timer = setInterval(refetch, 5000);
  onCleanup(() => clearInterval(timer));

  function showToast(msg: string, type: string) {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  }

  async function connect() {
    setLoading(true);
    try {
      const res = await fetch(`${API_BASE}/connect`, { method: "POST" });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
      showToast("VPN connecting...", "success");
      if (data.saml_url) {
        window.open(data.saml_url, "_blank");
      }
      setTimeout(refetch, 2000);
    } catch (e: any) {
      showToast(e.message, "error");
    } finally {
      setLoading(false);
    }
  }

  async function disconnect() {
    setLoading(true);
    try {
      const res = await fetch(`${API_BASE}/disconnect`, { method: "POST" });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
      showToast("VPN disconnected", "success");
      refetch();
    } catch (e: any) {
      showToast(e.message, "error");
    } finally {
      setLoading(false);
    }
  }

  const state = () => status()?.state || "disconnected";
  const isConnected = () => state() === "connected";
  const isConnecting = () => state() === "connecting";

  return (
    <div class="max-w-xl mx-auto px-5 py-10">
      <h1 class="text-2xl font-bold text-[#58a6ff] mb-6">OpenFortiVPN Control</h1>

      <Card>
        <div class="flex items-center gap-3 text-xl font-semibold mb-2">
          <StatusDot state={state()} />
          <span class="capitalize">{state()}</span>
        </div>

        {isConnected() && (
          <div class="grid grid-cols-[120px_1fr] gap-2 text-sm mt-3">
            <span class="text-gray-400">Interface</span>
            <span>{status()?.interface || "-"}</span>
            <span class="text-gray-400">IP Address</span>
            <span>{status()?.ip || "-"}</span>
            <span class="text-gray-400">Uptime</span>
            <span>{formatUptime(status()?.uptime_seconds)}</span>
          </div>
        )}

        <div class="flex gap-3 mt-5">
          <button
            onClick={connect}
            disabled={isConnected() || isConnecting() || loading()}
            class="px-5 py-2 bg-green-700 hover:bg-green-600 text-white rounded-md font-semibold disabled:opacity-50 disabled:cursor-not-allowed transition"
          >
            Connect
          </button>
          <button
            onClick={disconnect}
            disabled={!isConnected() && !isConnecting() || loading()}
            class="px-5 py-2 bg-red-700 hover:bg-red-600 text-white rounded-md font-semibold disabled:opacity-50 disabled:cursor-not-allowed transition"
          >
            Disconnect
          </button>
          <button
            onClick={refetch}
            class="px-5 py-2 bg-blue-700 hover:bg-blue-600 text-white rounded-md font-semibold transition"
          >
            Refresh
          </button>
        </div>
      </Card>

      <Card>
        <h2 class="text-lg font-semibold mb-3">Logs</h2>
        <div class="bg-[#0d1117] border border-[#30363d] rounded-md p-3 font-mono text-xs max-h-72 overflow-y-auto whitespace-pre-wrap">
          Use <code>docker logs</code> or <code>podman logs</code> to view container output.
        </div>
      </Card>

      {toast() && (
        <div
          class={`fixed top-5 right-5 px-5 py-3 rounded-md font-semibold shadow-lg transition-opacity ${
            toast()?.type === "success" ? "bg-green-700" : "bg-red-700"
          } text-white`}
        >
          {toast()?.msg}
        </div>
      )}
    </div>
  );
}
