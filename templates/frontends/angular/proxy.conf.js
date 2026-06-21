module.exports = [
  {
    context: ["/api"],
    target: process.env.API_TARGET || "http://localhost:3001",
    secure: false,
    changeOrigin: true,
  },
];
