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
    log_wasm: function (level, script_ptr, script_len) {
      const memory = instance.exports.memory;
      const memv = new Uint8Array(memory.buffer, script_ptr, script_len);
      var string = new TextDecoder().decode(memv);
      var log_fn = undefined
      switch (level) {
        case 3:
          log_fn = console.debug;
          break;
        case 2:
          log_fn = console.info;
          break;
        case 1:
          log_fn = console.warn;
          break;
        case 0:
          log_fn = console.error;
          break;
        default:
          log_fn = console.log;
          break;
      }
      log_fn(level,":",string);
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
    // term_div.width = window.innerWidth;
    // term_div.height = window.innerHeight;
    instance.exports.resize(window.innerWidth, window.innerHeight);
});
// term_div.style.width = window.innerWidth + "px";
// term_div.style.height = window.innerHeight + "px";

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

ws.onmessage = function(e) { 
  console.log("MESSAGE:", e);
};
ws.onclose = function(e) { 
  console.log("CLOSE:", e);
};

ws.onopen = function(e) { 
    console.log("OPEN:", e);
};