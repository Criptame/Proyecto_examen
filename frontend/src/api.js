const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

async function request(path, options = {}) {
  const res = await fetch(`${API_URL}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `Error ${res.status}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

export const getHealth = () => request('/health');
export const listTasks = () => request('/api/tasks');
export const createTask = (title) =>
  request('/api/tasks', { method: 'POST', body: JSON.stringify({ title }) });
export const updateTask = (id, patch) =>
  request(`/api/tasks/${id}`, { method: 'PUT', body: JSON.stringify(patch) });
export const deleteTask = (id) => request(`/api/tasks/${id}`, { method: 'DELETE' });
