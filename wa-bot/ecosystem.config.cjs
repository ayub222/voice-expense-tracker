module.exports = {
  apps: [
    {
      name: "voice-expense-wa-bot",
      script: "bot.js",
      cwd: __dirname,
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: "300M",
      env: {
        NODE_ENV: "production",
        PORT: "3000",
        API_BASE: "https://voice-expense-tracker-olive.vercel.app/api.php",
      },
    },
  ],
};
