// Ganti ini ke alamat backend lu (localhost pas dev, atau URL Service/Ingress pas udah di Kubernetes)
const API_BASE = window.MINISOC_API_BASE || "http://localhost:8000";

let token = localStorage.getItem("minisoc_token") || null;

function showApp() {
  document.getElementById("auth-section").classList.add("hidden");
  document.getElementById("app-section").classList.remove("hidden");
  loadTickets();
}

if (token) showApp();

function logout() {
  token = null;
  localStorage.removeItem("minisoc_token");
  document.getElementById("app-section").classList.add("hidden");
  document.getElementById("auth-section").classList.remove("hidden");
  document.getElementById("login-username").value = "";
  document.getElementById("login-password").value = "";
  document.getElementById("auth-message").textContent = "";
}

async function register() {
  const username = document.getElementById("login-username").value;
  const password = document.getElementById("login-password").value;
  const res = await fetch(`${API_BASE}/auth/register`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username, password }),
  });
  const msg = document.getElementById("auth-message");
  if (res.ok) {
    msg.textContent = "Registrasi berhasil, silakan login.";
  } else {
    const err = await res.json();
    msg.textContent = "Gagal: " + (err.detail || res.statusText);
  }
}

async function login() {
  const username = document.getElementById("login-username").value;
  const password = document.getElementById("login-password").value;

  const form = new URLSearchParams();
  form.append("username", username);
  form.append("password", password);

  const res = await fetch(`${API_BASE}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: form,
  });

  const msg = document.getElementById("auth-message");
  if (res.ok) {
    const data = await res.json();
    token = data.access_token;
    localStorage.setItem("minisoc_token", token);
    showApp();
  } else {
    msg.textContent = "Login gagal, cek username/password.";
  }
}

async function loadTickets() {
  const res = await fetch(`${API_BASE}/tickets`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) return;
  const tickets = await res.json();
  const body = document.getElementById("tickets-body");
  body.innerHTML = "";
  tickets.forEach((t) => {
    const row = document.createElement("tr");
    row.innerHTML = `
      <td>${t.id}</td>
      <td>${t.title}</td>
      <td>${t.severity}</td>
      <td>${t.status}</td>
      <td>${t.source}</td>
      <td><button onclick="deleteTicket(${t.id})">Hapus</button></td>
    `;
    body.appendChild(row);
  });
}

async function createTicket() {
  const title = document.getElementById("ticket-title").value;
  const description = document.getElementById("ticket-description").value;
  const severity = document.getElementById("ticket-severity").value;

  await fetch(`${API_BASE}/tickets`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ title, description, severity, source: "manual" }),
  });

  document.getElementById("ticket-title").value = "";
  document.getElementById("ticket-description").value = "";
  loadTickets();
}

async function deleteTicket(id) {
  await fetch(`${API_BASE}/tickets/${id}`, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${token}` },
  });
  loadTickets();
}
