import { useEffect, useState } from "react";
import {
  LineChart, BarChart, PieChart, Pie, Line, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer
} from "recharts";

export default function App() {
  const [data, setData] = useState([]);
  const [chartType, setChartType] = useState("line");
  const [devices, setDevices] = useState([]);
  const [selectedDevice, setSelectedDevice] = useState("");
  const [command, setCommand] = useState("");

  useEffect(() => {
    fetch("/api/devices").then(res => res.json()).then(setDevices);
  }, []);

  useEffect(() => {
    if (selectedDevice) {
      fetch(`/api/sensor-data?device_id=${selectedDevice}&limit=100`)
        .then(res => res.json()).then(setData);
    }
  }, [selectedDevice]);

  const sendCommand = () => {
    fetch("/api/send-command", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ device_id: selectedDevice, command })
    }).then(res => res.json()).then(console.log);
  };

  return (
    <div className="p-4">
      <h1 className="text-2xl font-bold mb-4">Visualizador del Huerto</h1>
      <div className="flex flex-col md:flex-row gap-4 items-center mb-4">
        <select
          className="p-2 border"
          value={selectedDevice}
          onChange={e => setSelectedDevice(e.target.value)}
        >
          <option value="">Seleccione un dispositivo</option>
          {devices.map(dev => <option key={dev}>{dev}</option>)}
        </select>
        <select
          className="p-2 border"
          value={chartType}
          onChange={e => setChartType(e.target.value)}
        >
          <option value="line">Líneas</option>
          <option value="bar">Barras</option>
          <option value="pie">Quesito (humedad)</option>
        </select>
        <input
          className="p-2 border"
          placeholder="Comando"
          value={command}
          onChange={e => setCommand(e.target.value)}
        />
        <button className="bg-blue-500 text-white px-4 py-2" onClick={sendCommand}>
          Enviar Comando
        </button>
      </div>

      <div style={{ width: "100%", height: 400 }}>
        <ResponsiveContainer>
          {chartType === "line" && (
            <LineChart data={data}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="timestamp" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Line type="monotone" dataKey="temp_ambient" stroke="#8884d8" name="Temp Ambiente" />
              <Line type="monotone" dataKey="temp_soil" stroke="#82ca9d" name="Temp Suelo" />
            </LineChart>
          )}
          {chartType === "bar" && (
            <BarChart data={data}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="timestamp" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Bar dataKey="light_level" fill="#ffc658" name="Luz" />
            </BarChart>
          )}
          {chartType === "pie" && data.length > 0 && (
            <PieChart>
              <Pie
                data={[
                  { name: "Humedad Ambiente", value: data[data.length - 1].humidity_ambient },
                  { name: "Humedad Suelo", value: data[data.length - 1].humidity_soil },
                ]}
                dataKey="value"
                nameKey="name"
                cx="50%"
                cy="50%"
                outerRadius={100}
                fill="#8884d8"
                label
              />
              <Tooltip />
            </PieChart>
          )}
        </ResponsiveContainer>
      </div>
    </div>
  );
}
