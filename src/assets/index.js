var client = fetch("/client.wasm");

let term_div = document.getElementById('terminal');
let instance = undefined;
var importObject = {
  env: {
    eval: function (script_ptr, script_len) {
      const memory = instance.exports.memory;
      const memv = new Uint8Array(memory.buffer, script_ptr, script_len);
      var string = new TextDecoder().decode(memv);
      return eval(string);
    },
    log_wasm: function (script_ptr, script_len) {
      const memory = instance.exports.memory;
      const memv = new Uint8Array(memory.buffer, script_ptr, script_len);
      var string = new TextDecoder().decode(memv);
      console.log(string);
    }
  },
};

WebAssembly.instantiateStreaming(client, importObject)
  .then((res) => {
    instance = res.instance;
    instance.exports.main();
  },
)
.catch(error=>{
  console.log('there was some error; ', error)
});
window.addEventListener("resize", (ev)=>{
    term_div.width = window.innerWidth;
    term_div.height = window.innerHeight;
    instance.exports.resize(window.innerWidth, window.innerHeight);
});

var term = new Terminal();
term.open(term_div);
// term.write('Hello from \x1B[1;3;31mxterm.js\x1B[0m $ ');

var ws_url = new URL(document.location.href);
ws_proto_map = {
  "http:": "ws:",
  "https:": "wss:",
}
ws_url.protocol = ws_proto_map[ws_url.protocol];
ws_url.pathname = "/chat";
console.log("Connecting Websocket:" ,ws_url.href);

var ws = new WebSocket(ws_url.href);
const attachAddon = new AttachAddon.AttachAddon(ws);
term.loadAddon(attachAddon);

// ws.onmessage = function(e) { 
//   console.log("MESSAGE:", e);
// };
// ws.onclose = function(e) { 
//   console.log("CLOSE:", e);
// };

// ws.onopen = function(e) { 
//     console.log("OPEN:", e);
// };