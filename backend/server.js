require("dotenv").config();
const express = require("express");
const cors = require("cors");
const http = require("http");
const rateLimiter = require("./middleware/rateLimiter");
const errorHandler = require("./middleware/errorHandler");
const { initWebSocket } = require("./services/websocketService");

const authRoutes = require("./routes/authRoutes");
const viagensRoutes = require("./routes/viagensRoutes");
const placesRoutes = require("./routes/placesRoutes");
const distanceRoutes = require("./routes/distanceRoutes");
const timelineRoutes = require("./routes/timelineRoutes");
const timelineController = require("./controllers/timelineController");
const wishlistRoutes = require("./routes/wishlistRoutes");
const suggestionsRoutes = require("./routes/suggestionsRoutes");
const { authRequired } = require("./middleware/auth");

const app = express();
const isProd = process.env.NODE_ENV === "production";
const allowedOrigins = isProd
  ? ["https://agentepessoaldaviagem.netlify.app"]
  : [
      "https://agentepessoaldaviagem.netlify.app",
      "http://localhost:3000",
      "http://localhost:5000",
      "http://localhost:5173",
      "http://127.0.0.1:3000",
      "http://127.0.0.1:5000",
      "http://127.0.0.1:5173",
    ];

const corsOptions = {
  origin(origin, callback) {
    // Requests sem origin (curl/Postman/apps mobile) também devem funcionar.
    if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error("CORS origin não permitida."));
  },
  methods: "GET,HEAD,PUT,PATCH,POST,DELETE",
  credentials: true,
  optionsSuccessStatus: 204,
};

app.use(cors(corsOptions));
app.use(express.json());
app.use(rateLimiter);

app.get("/health", (req, res) => res.json({ ok: true }));
app.use("/api/auth", authRoutes);
app.use("/api/viagens", viagensRoutes);
app.use("/api/places", placesRoutes);
app.use("/api/distance", distanceRoutes);
// POST especifico antes do router (garante match; evita "Cannot POST" em processos antigos)
app.post(
  "/api/timeline/:viagemId/gerar-tempo-livre-dias",
  authRequired,
  timelineController.gerarTempoLivrePorDia
);
app.use("/api/timeline", timelineRoutes);
app.use("/api/wishlist", wishlistRoutes);
app.use("/api/suggestions", suggestionsRoutes);
app.use(errorHandler);

const server = http.createServer(app);
initWebSocket(server);

const port = Number(process.env.PORT || 5000);
server.listen(port, () => {
  console.log(`Backend iniciado na porta ${port}`);
});
