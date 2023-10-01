var client = fetch("/client.wasm");
    
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
var term = new Terminal();
term.open(document.getElementById('terminal'));
term.write('Hello from \x1B[1;3;31mxterm.js\x1B[0m $ ')
let canvas = document.getElementById("canvas");
window.addEventListener("resize", (ev)=>{
    let canvas = document.getElementById("canvas");
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
    instance.exports.resize(window.innerWidth, window.innerHeight);
});