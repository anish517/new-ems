const protocol = window.location.protocol;
const host = window.location.host;

const fullHostUrl = `${protocol}//${host}`;

const api = axios.create({
  baseURL: fullHostUrl,
  timeout: 10000,
  headers: {
    "Content-Type": "application/json",
    "X-CSRFToken": getCookie("csrftoken"),
  },
});
