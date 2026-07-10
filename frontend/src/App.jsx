import React, { useEffect, useState } from 'react';
import { getHealth, listTasks, createTask, updateTask, deleteTask } from './api';

export default function App() {
  const [tasks, setTasks] = useState([]);
  const [title, setTitle] = useState('');
  const [health, setHealth] = useState(null);
  const [error, setError] = useState('');

  const refresh = async () => {
    try {
      setError('');
      const [h, t] = await Promise.all([getHealth(), listTasks()]);
      setHealth(h);
      setTasks(t);
    } catch (err) {
      setError(err.message);
    }
  };

  useEffect(() => {
    refresh();
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!title.trim()) return;
    await createTask(title);
    setTitle('');
    refresh();
  };

  const toggleDone = async (task) => {
    await updateTask(task.id, { done: !task.done });
    refresh();
  };

  const remove = async (id) => {
    await deleteTask(id);
    refresh();
  };

  return (
    <main className="container">
      <h1>EFT DevOps &mdash; Gestor de Tareas</h1>
      <p className="status">
        Backend:{' '}
        <span className={health?.status === 'ok' ? 'ok' : 'down'}>
          {health ? `${health.status} (db: ${health.db})` : 'sin conexion'}
        </span>
      </p>

      <form onSubmit={handleSubmit} className="form">
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Nueva tarea..."
        />
        <button type="submit">Agregar</button>
      </form>

      {error && <p className="error">{error}</p>}

      <ul className="task-list">
        {tasks.map((task) => (
          <li key={task.id} className={task.done ? 'done' : ''}>
            <label>
              <input
                type="checkbox"
                checked={task.done}
                onChange={() => toggleDone(task)}
              />
              {task.title}
            </label>
            <button onClick={() => remove(task.id)}>Eliminar</button>
          </li>
        ))}
      </ul>
    </main>
  );
}
