
let qjs = null;
let qjsCtx = null;

// async function initModQJS() {
//     console.log("Module chargé !");
//     await initQJS();
//     setProp("globalThis", "x", 42);
//     let code = "'Hello from QuickJS!' + x";

//     const add = qjsCtx.newFunction("add", (...args) => {
//         const nativeArgs = args.map(qjsCtx.dump)
//         const a = nativeArgs[0];
//         const b = nativeArgs[1];
//         return qjsCtx.newNumber(a + b);
//     });

//     qjsCtx.setProp(qjsCtx.global, "add", add);

//     evalInQJS(code);
//     evalInQJS('add(5, 7)');
// }

async function initQJS() {
    if (!qjs) {
        console.debug("Loading QuickJS...");
        qjs = await getQuickJS();
        console.debug("QuickJS loaded:", qjs);
    }

    if (!qjsCtx) {
        qjsCtx = qjs.newContext();
    }

    return true;
}

function evalInQJS(code) {
    if (!qjsCtx) {
        throw new Error("QuickJS context is not initialized. Call initQJS() first.");
    }
    const ctx = qjsCtx;
    exposeDartApiToQuickJS(ctx, globalThis.dartApi);

    const result = ctx.evalCode(code);
    let out = null;
    if (result.error) {
        console.log("Execution evalInQJS failed:", ctx.dump(result.error))
    } else {
        out = ctx.dump(result.value);
        // console.log("Success: evalInQJS", out)
    }

    result.dispose();
    return out;
}

function setProp(targetExpr, propName, value) {
    if (!qjsCtx) {
        throw new Error("QuickJS context is not initialized. Call initQJS() first.");
    }

    const ctx = qjsCtx;

    const target = String(targetExpr);
    const key = JSON.stringify(String(propName));
    const serializedValue = JSON.stringify(value);
    const jsValue = serializedValue === undefined ? "undefined" : serializedValue;
    const code = `(${target})[${key}] = ${jsValue};`;

    const result = ctx.evalCode(code);
    if (result.error) {
        console.log("setProp failed:", ctx.dump(result.error));
    }

    result.dispose();
}

function disposeQJS() {
    if (qjsCtx) {
        qjsCtx.dispose();
        qjsCtx = null;
    }
}


function wrapDartFunction(ctx, jsFunc) {
    return ctx.newFunction("dartCallback", (...args) => {
        try {
            // Convertit les arguments QuickJS → JS natif
            const nativeArgs = args.map(a => ctx.dump(a));

            // Appel vers Dart
            const result = jsFunc(...nativeArgs);

            // Si Dart renvoie une Promise → QuickJS doit recevoir une Promise
            if (result instanceof Promise) {
                const { promise, resolve, reject } = ctx.newPromise();

                result.then(
                    value => resolve(wrapValue(ctx, value)),
                    err => reject(ctx.newString(String(err)))
                );

                return promise;
            }

            // Sinon valeur simple
            return wrapValue(ctx, result);

        } catch (e) {
            return ctx.throw(String(e));
        }
    });
}

function exposeDartApiToQuickJS(ctx, dartApi) {
    const qjsApi = ctx.newObject();

    for (const key of Object.keys(dartApi)) {
        const fn = dartApi[key];
        if (typeof fn === "function") {
            ctx.setProp(qjsApi, key, wrapDartFunction(ctx, fn));
        }
    }

    ctx.setProp(ctx.global, "dart", qjsApi);
}


function wrapValue(ctx, value) {
  switch (typeof value) {
    case "number":
      return ctx.newNumber(value);

    case "string":
      return ctx.newString(value);

    case "boolean":
      return ctx.newBool(value);

    case "undefined":
      return ctx.undefined;

    case "object":
      if (value === null) return ctx.null;
      if (Array.isArray(value)) return wrapArray(ctx, value);
      return wrapObject(ctx, value);

    default:
      throw new Error("Unsupported type: " + typeof value);
  }
}

function wrapObject(ctx, obj) {
  const qObj = ctx.newObject();

  for (const key of Object.keys(obj)) {
    ctx.setProp(qObj, key, wrapValue(ctx, obj[key]));
  }

  return qObj;
}

function wrapArray(ctx, arr) {
  const qArr = ctx.newArray();

  for (let i = 0; i < arr.length; i++) {
    ctx.setIndex(qArr, i, wrapValue(ctx, arr[i]));
  }

  return qArr;
}

//initModQJS(); // ← exécuté automatiquement au moment de l'import
