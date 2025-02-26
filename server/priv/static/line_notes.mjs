// build/dev/javascript/prelude.mjs
var CustomType = class {
  withFields(fields) {
    let properties = Object.keys(this).map(
      (label) => label in fields ? fields[label] : this[label]
    );
    return new this.constructor(...properties);
  }
};
var List = class {
  static fromArray(array3, tail) {
    let t = tail || new Empty();
    for (let i = array3.length - 1; i >= 0; --i) {
      t = new NonEmpty(array3[i], t);
    }
    return t;
  }
  [Symbol.iterator]() {
    return new ListIterator(this);
  }
  toArray() {
    return [...this];
  }
  // @internal
  atLeastLength(desired) {
    for (let _ of this) {
      if (desired <= 0)
        return true;
      desired--;
    }
    return desired <= 0;
  }
  // @internal
  hasLength(desired) {
    for (let _ of this) {
      if (desired <= 0)
        return false;
      desired--;
    }
    return desired === 0;
  }
  // @internal
  countLength() {
    let length3 = 0;
    for (let _ of this)
      length3++;
    return length3;
  }
};
function prepend(element2, tail) {
  return new NonEmpty(element2, tail);
}
function toList(elements2, tail) {
  return List.fromArray(elements2, tail);
}
var ListIterator = class {
  #current;
  constructor(current) {
    this.#current = current;
  }
  next() {
    if (this.#current instanceof Empty) {
      return { done: true };
    } else {
      let { head, tail } = this.#current;
      this.#current = tail;
      return { value: head, done: false };
    }
  }
};
var Empty = class extends List {
};
var NonEmpty = class extends List {
  constructor(head, tail) {
    super();
    this.head = head;
    this.tail = tail;
  }
};
var BitArray = class _BitArray {
  constructor(buffer) {
    if (!(buffer instanceof Uint8Array)) {
      throw "BitArray can only be constructed from a Uint8Array";
    }
    this.buffer = buffer;
  }
  // @internal
  get length() {
    return this.buffer.length;
  }
  // @internal
  byteAt(index4) {
    return this.buffer[index4];
  }
  // @internal
  floatFromSlice(start2, end, isBigEndian) {
    return byteArrayToFloat(this.buffer, start2, end, isBigEndian);
  }
  // @internal
  intFromSlice(start2, end, isBigEndian, isSigned) {
    return byteArrayToInt(this.buffer, start2, end, isBigEndian, isSigned);
  }
  // @internal
  binaryFromSlice(start2, end) {
    const buffer = new Uint8Array(
      this.buffer.buffer,
      this.buffer.byteOffset + start2,
      end - start2
    );
    return new _BitArray(buffer);
  }
  // @internal
  sliceAfter(index4) {
    const buffer = new Uint8Array(
      this.buffer.buffer,
      this.buffer.byteOffset + index4,
      this.buffer.byteLength - index4
    );
    return new _BitArray(buffer);
  }
};
var UtfCodepoint = class {
  constructor(value3) {
    this.value = value3;
  }
};
function byteArrayToInt(byteArray, start2, end, isBigEndian, isSigned) {
  const byteSize = end - start2;
  if (byteSize <= 6) {
    let value3 = 0;
    if (isBigEndian) {
      for (let i = start2; i < end; i++) {
        value3 = value3 * 256 + byteArray[i];
      }
    } else {
      for (let i = end - 1; i >= start2; i--) {
        value3 = value3 * 256 + byteArray[i];
      }
    }
    if (isSigned) {
      const highBit = 2 ** (byteSize * 8 - 1);
      if (value3 >= highBit) {
        value3 -= highBit * 2;
      }
    }
    return value3;
  } else {
    let value3 = 0n;
    if (isBigEndian) {
      for (let i = start2; i < end; i++) {
        value3 = (value3 << 8n) + BigInt(byteArray[i]);
      }
    } else {
      for (let i = end - 1; i >= start2; i--) {
        value3 = (value3 << 8n) + BigInt(byteArray[i]);
      }
    }
    if (isSigned) {
      const highBit = 1n << BigInt(byteSize * 8 - 1);
      if (value3 >= highBit) {
        value3 -= highBit * 2n;
      }
    }
    return Number(value3);
  }
}
function byteArrayToFloat(byteArray, start2, end, isBigEndian) {
  const view2 = new DataView(byteArray.buffer);
  const byteSize = end - start2;
  if (byteSize === 8) {
    return view2.getFloat64(start2, !isBigEndian);
  } else if (byteSize === 4) {
    return view2.getFloat32(start2, !isBigEndian);
  } else {
    const msg = `Sized floats must be 32-bit or 64-bit on JavaScript, got size of ${byteSize * 8} bits`;
    throw new globalThis.Error(msg);
  }
}
var Result = class _Result extends CustomType {
  // @internal
  static isResult(data) {
    return data instanceof _Result;
  }
};
var Ok = class extends Result {
  constructor(value3) {
    super();
    this[0] = value3;
  }
  // @internal
  isOk() {
    return true;
  }
};
var Error = class extends Result {
  constructor(detail) {
    super();
    this[0] = detail;
  }
  // @internal
  isOk() {
    return false;
  }
};
function isEqual(x, y) {
  let values2 = [x, y];
  while (values2.length) {
    let a = values2.pop();
    let b = values2.pop();
    if (a === b)
      continue;
    if (!isObject(a) || !isObject(b))
      return false;
    let unequal = !structurallyCompatibleObjects(a, b) || unequalDates(a, b) || unequalBuffers(a, b) || unequalArrays(a, b) || unequalMaps(a, b) || unequalSets(a, b) || unequalRegExps(a, b);
    if (unequal)
      return false;
    const proto = Object.getPrototypeOf(a);
    if (proto !== null && typeof proto.equals === "function") {
      try {
        if (a.equals(b))
          continue;
        else
          return false;
      } catch {
      }
    }
    let [keys2, get] = getters(a);
    for (let k of keys2(a)) {
      values2.push(get(a, k), get(b, k));
    }
  }
  return true;
}
function getters(object3) {
  if (object3 instanceof Map) {
    return [(x) => x.keys(), (x, y) => x.get(y)];
  } else {
    let extra = object3 instanceof globalThis.Error ? ["message"] : [];
    return [(x) => [...extra, ...Object.keys(x)], (x, y) => x[y]];
  }
}
function unequalDates(a, b) {
  return a instanceof Date && (a > b || a < b);
}
function unequalBuffers(a, b) {
  return a.buffer instanceof ArrayBuffer && a.BYTES_PER_ELEMENT && !(a.byteLength === b.byteLength && a.every((n, i) => n === b[i]));
}
function unequalArrays(a, b) {
  return Array.isArray(a) && a.length !== b.length;
}
function unequalMaps(a, b) {
  return a instanceof Map && a.size !== b.size;
}
function unequalSets(a, b) {
  return a instanceof Set && (a.size != b.size || [...a].some((e) => !b.has(e)));
}
function unequalRegExps(a, b) {
  return a instanceof RegExp && (a.source !== b.source || a.flags !== b.flags);
}
function isObject(a) {
  return typeof a === "object" && a !== null;
}
function structurallyCompatibleObjects(a, b) {
  if (typeof a !== "object" && typeof b !== "object" && (!a || !b))
    return false;
  let nonstructural = [Promise, WeakSet, WeakMap, Function];
  if (nonstructural.some((c) => a instanceof c))
    return false;
  return a.constructor === b.constructor;
}
function remainderInt(a, b) {
  if (b === 0) {
    return 0;
  } else {
    return a % b;
  }
}
function divideInt(a, b) {
  return Math.trunc(divideFloat(a, b));
}
function divideFloat(a, b) {
  if (b === 0) {
    return 0;
  } else {
    return a / b;
  }
}
function makeError(variant, module, line, fn, message, extra) {
  let error = new globalThis.Error(message);
  error.gleam_error = variant;
  error.module = module;
  error.line = line;
  error.function = fn;
  error.fn = fn;
  for (let k in extra)
    error[k] = extra[k];
  return error;
}

// build/dev/javascript/gleam_stdlib/gleam/option.mjs
var Some = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var None = class extends CustomType {
};
function to_result(option, e) {
  if (option instanceof Some) {
    let a = option[0];
    return new Ok(a);
  } else {
    return new Error(e);
  }
}
function map(option, fun) {
  if (option instanceof Some) {
    let x = option[0];
    return new Some(fun(x));
  } else {
    return new None();
  }
}
function flatten(option) {
  if (option instanceof Some) {
    let x = option[0];
    return x;
  } else {
    return new None();
  }
}

// build/dev/javascript/gleam_stdlib/dict.mjs
var referenceMap = /* @__PURE__ */ new WeakMap();
var tempDataView = new DataView(new ArrayBuffer(8));
var referenceUID = 0;
function hashByReference(o) {
  const known = referenceMap.get(o);
  if (known !== void 0) {
    return known;
  }
  const hash = referenceUID++;
  if (referenceUID === 2147483647) {
    referenceUID = 0;
  }
  referenceMap.set(o, hash);
  return hash;
}
function hashMerge(a, b) {
  return a ^ b + 2654435769 + (a << 6) + (a >> 2) | 0;
}
function hashString(s) {
  let hash = 0;
  const len = s.length;
  for (let i = 0; i < len; i++) {
    hash = Math.imul(31, hash) + s.charCodeAt(i) | 0;
  }
  return hash;
}
function hashNumber(n) {
  tempDataView.setFloat64(0, n);
  const i = tempDataView.getInt32(0);
  const j = tempDataView.getInt32(4);
  return Math.imul(73244475, i >> 16 ^ i) ^ j;
}
function hashBigInt(n) {
  return hashString(n.toString());
}
function hashObject(o) {
  const proto = Object.getPrototypeOf(o);
  if (proto !== null && typeof proto.hashCode === "function") {
    try {
      const code = o.hashCode(o);
      if (typeof code === "number") {
        return code;
      }
    } catch {
    }
  }
  if (o instanceof Promise || o instanceof WeakSet || o instanceof WeakMap) {
    return hashByReference(o);
  }
  if (o instanceof Date) {
    return hashNumber(o.getTime());
  }
  let h = 0;
  if (o instanceof ArrayBuffer) {
    o = new Uint8Array(o);
  }
  if (Array.isArray(o) || o instanceof Uint8Array) {
    for (let i = 0; i < o.length; i++) {
      h = Math.imul(31, h) + getHash(o[i]) | 0;
    }
  } else if (o instanceof Set) {
    o.forEach((v) => {
      h = h + getHash(v) | 0;
    });
  } else if (o instanceof Map) {
    o.forEach((v, k) => {
      h = h + hashMerge(getHash(v), getHash(k)) | 0;
    });
  } else {
    const keys2 = Object.keys(o);
    for (let i = 0; i < keys2.length; i++) {
      const k = keys2[i];
      const v = o[k];
      h = h + hashMerge(getHash(v), hashString(k)) | 0;
    }
  }
  return h;
}
function getHash(u) {
  if (u === null)
    return 1108378658;
  if (u === void 0)
    return 1108378659;
  if (u === true)
    return 1108378657;
  if (u === false)
    return 1108378656;
  switch (typeof u) {
    case "number":
      return hashNumber(u);
    case "string":
      return hashString(u);
    case "bigint":
      return hashBigInt(u);
    case "object":
      return hashObject(u);
    case "symbol":
      return hashByReference(u);
    case "function":
      return hashByReference(u);
    default:
      return 0;
  }
}
var SHIFT = 5;
var BUCKET_SIZE = Math.pow(2, SHIFT);
var MASK = BUCKET_SIZE - 1;
var MAX_INDEX_NODE = BUCKET_SIZE / 2;
var MIN_ARRAY_NODE = BUCKET_SIZE / 4;
var ENTRY = 0;
var ARRAY_NODE = 1;
var INDEX_NODE = 2;
var COLLISION_NODE = 3;
var EMPTY = {
  type: INDEX_NODE,
  bitmap: 0,
  array: []
};
function mask(hash, shift) {
  return hash >>> shift & MASK;
}
function bitpos(hash, shift) {
  return 1 << mask(hash, shift);
}
function bitcount(x) {
  x -= x >> 1 & 1431655765;
  x = (x & 858993459) + (x >> 2 & 858993459);
  x = x + (x >> 4) & 252645135;
  x += x >> 8;
  x += x >> 16;
  return x & 127;
}
function index(bitmap, bit) {
  return bitcount(bitmap & bit - 1);
}
function cloneAndSet(arr, at, val) {
  const len = arr.length;
  const out = new Array(len);
  for (let i = 0; i < len; ++i) {
    out[i] = arr[i];
  }
  out[at] = val;
  return out;
}
function spliceIn(arr, at, val) {
  const len = arr.length;
  const out = new Array(len + 1);
  let i = 0;
  let g = 0;
  while (i < at) {
    out[g++] = arr[i++];
  }
  out[g++] = val;
  while (i < len) {
    out[g++] = arr[i++];
  }
  return out;
}
function spliceOut(arr, at) {
  const len = arr.length;
  const out = new Array(len - 1);
  let i = 0;
  let g = 0;
  while (i < at) {
    out[g++] = arr[i++];
  }
  ++i;
  while (i < len) {
    out[g++] = arr[i++];
  }
  return out;
}
function createNode(shift, key1, val1, key2hash, key2, val2) {
  const key1hash = getHash(key1);
  if (key1hash === key2hash) {
    return {
      type: COLLISION_NODE,
      hash: key1hash,
      array: [
        { type: ENTRY, k: key1, v: val1 },
        { type: ENTRY, k: key2, v: val2 }
      ]
    };
  }
  const addedLeaf = { val: false };
  return assoc(
    assocIndex(EMPTY, shift, key1hash, key1, val1, addedLeaf),
    shift,
    key2hash,
    key2,
    val2,
    addedLeaf
  );
}
function assoc(root, shift, hash, key, val, addedLeaf) {
  switch (root.type) {
    case ARRAY_NODE:
      return assocArray(root, shift, hash, key, val, addedLeaf);
    case INDEX_NODE:
      return assocIndex(root, shift, hash, key, val, addedLeaf);
    case COLLISION_NODE:
      return assocCollision(root, shift, hash, key, val, addedLeaf);
  }
}
function assocArray(root, shift, hash, key, val, addedLeaf) {
  const idx = mask(hash, shift);
  const node = root.array[idx];
  if (node === void 0) {
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root.size + 1,
      array: cloneAndSet(root.array, idx, { type: ENTRY, k: key, v: val })
    };
  }
  if (node.type === ENTRY) {
    if (isEqual(key, node.k)) {
      if (val === node.v) {
        return root;
      }
      return {
        type: ARRAY_NODE,
        size: root.size,
        array: cloneAndSet(root.array, idx, {
          type: ENTRY,
          k: key,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root.size,
      array: cloneAndSet(
        root.array,
        idx,
        createNode(shift + SHIFT, node.k, node.v, hash, key, val)
      )
    };
  }
  const n = assoc(node, shift + SHIFT, hash, key, val, addedLeaf);
  if (n === node) {
    return root;
  }
  return {
    type: ARRAY_NODE,
    size: root.size,
    array: cloneAndSet(root.array, idx, n)
  };
}
function assocIndex(root, shift, hash, key, val, addedLeaf) {
  const bit = bitpos(hash, shift);
  const idx = index(root.bitmap, bit);
  if ((root.bitmap & bit) !== 0) {
    const node = root.array[idx];
    if (node.type !== ENTRY) {
      const n = assoc(node, shift + SHIFT, hash, key, val, addedLeaf);
      if (n === node) {
        return root;
      }
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap,
        array: cloneAndSet(root.array, idx, n)
      };
    }
    const nodeKey = node.k;
    if (isEqual(key, nodeKey)) {
      if (val === node.v) {
        return root;
      }
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap,
        array: cloneAndSet(root.array, idx, {
          type: ENTRY,
          k: key,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: INDEX_NODE,
      bitmap: root.bitmap,
      array: cloneAndSet(
        root.array,
        idx,
        createNode(shift + SHIFT, nodeKey, node.v, hash, key, val)
      )
    };
  } else {
    const n = root.array.length;
    if (n >= MAX_INDEX_NODE) {
      const nodes = new Array(32);
      const jdx = mask(hash, shift);
      nodes[jdx] = assocIndex(EMPTY, shift + SHIFT, hash, key, val, addedLeaf);
      let j = 0;
      let bitmap = root.bitmap;
      for (let i = 0; i < 32; i++) {
        if ((bitmap & 1) !== 0) {
          const node = root.array[j++];
          nodes[i] = node;
        }
        bitmap = bitmap >>> 1;
      }
      return {
        type: ARRAY_NODE,
        size: n + 1,
        array: nodes
      };
    } else {
      const newArray = spliceIn(root.array, idx, {
        type: ENTRY,
        k: key,
        v: val
      });
      addedLeaf.val = true;
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap | bit,
        array: newArray
      };
    }
  }
}
function assocCollision(root, shift, hash, key, val, addedLeaf) {
  if (hash === root.hash) {
    const idx = collisionIndexOf(root, key);
    if (idx !== -1) {
      const entry = root.array[idx];
      if (entry.v === val) {
        return root;
      }
      return {
        type: COLLISION_NODE,
        hash,
        array: cloneAndSet(root.array, idx, { type: ENTRY, k: key, v: val })
      };
    }
    const size = root.array.length;
    addedLeaf.val = true;
    return {
      type: COLLISION_NODE,
      hash,
      array: cloneAndSet(root.array, size, { type: ENTRY, k: key, v: val })
    };
  }
  return assoc(
    {
      type: INDEX_NODE,
      bitmap: bitpos(root.hash, shift),
      array: [root]
    },
    shift,
    hash,
    key,
    val,
    addedLeaf
  );
}
function collisionIndexOf(root, key) {
  const size = root.array.length;
  for (let i = 0; i < size; i++) {
    if (isEqual(key, root.array[i].k)) {
      return i;
    }
  }
  return -1;
}
function find(root, shift, hash, key) {
  switch (root.type) {
    case ARRAY_NODE:
      return findArray(root, shift, hash, key);
    case INDEX_NODE:
      return findIndex(root, shift, hash, key);
    case COLLISION_NODE:
      return findCollision(root, key);
  }
}
function findArray(root, shift, hash, key) {
  const idx = mask(hash, shift);
  const node = root.array[idx];
  if (node === void 0) {
    return void 0;
  }
  if (node.type !== ENTRY) {
    return find(node, shift + SHIFT, hash, key);
  }
  if (isEqual(key, node.k)) {
    return node;
  }
  return void 0;
}
function findIndex(root, shift, hash, key) {
  const bit = bitpos(hash, shift);
  if ((root.bitmap & bit) === 0) {
    return void 0;
  }
  const idx = index(root.bitmap, bit);
  const node = root.array[idx];
  if (node.type !== ENTRY) {
    return find(node, shift + SHIFT, hash, key);
  }
  if (isEqual(key, node.k)) {
    return node;
  }
  return void 0;
}
function findCollision(root, key) {
  const idx = collisionIndexOf(root, key);
  if (idx < 0) {
    return void 0;
  }
  return root.array[idx];
}
function without(root, shift, hash, key) {
  switch (root.type) {
    case ARRAY_NODE:
      return withoutArray(root, shift, hash, key);
    case INDEX_NODE:
      return withoutIndex(root, shift, hash, key);
    case COLLISION_NODE:
      return withoutCollision(root, key);
  }
}
function withoutArray(root, shift, hash, key) {
  const idx = mask(hash, shift);
  const node = root.array[idx];
  if (node === void 0) {
    return root;
  }
  let n = void 0;
  if (node.type === ENTRY) {
    if (!isEqual(node.k, key)) {
      return root;
    }
  } else {
    n = without(node, shift + SHIFT, hash, key);
    if (n === node) {
      return root;
    }
  }
  if (n === void 0) {
    if (root.size <= MIN_ARRAY_NODE) {
      const arr = root.array;
      const out = new Array(root.size - 1);
      let i = 0;
      let j = 0;
      let bitmap = 0;
      while (i < idx) {
        const nv = arr[i];
        if (nv !== void 0) {
          out[j] = nv;
          bitmap |= 1 << i;
          ++j;
        }
        ++i;
      }
      ++i;
      while (i < arr.length) {
        const nv = arr[i];
        if (nv !== void 0) {
          out[j] = nv;
          bitmap |= 1 << i;
          ++j;
        }
        ++i;
      }
      return {
        type: INDEX_NODE,
        bitmap,
        array: out
      };
    }
    return {
      type: ARRAY_NODE,
      size: root.size - 1,
      array: cloneAndSet(root.array, idx, n)
    };
  }
  return {
    type: ARRAY_NODE,
    size: root.size,
    array: cloneAndSet(root.array, idx, n)
  };
}
function withoutIndex(root, shift, hash, key) {
  const bit = bitpos(hash, shift);
  if ((root.bitmap & bit) === 0) {
    return root;
  }
  const idx = index(root.bitmap, bit);
  const node = root.array[idx];
  if (node.type !== ENTRY) {
    const n = without(node, shift + SHIFT, hash, key);
    if (n === node) {
      return root;
    }
    if (n !== void 0) {
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap,
        array: cloneAndSet(root.array, idx, n)
      };
    }
    if (root.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root.bitmap ^ bit,
      array: spliceOut(root.array, idx)
    };
  }
  if (isEqual(key, node.k)) {
    if (root.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root.bitmap ^ bit,
      array: spliceOut(root.array, idx)
    };
  }
  return root;
}
function withoutCollision(root, key) {
  const idx = collisionIndexOf(root, key);
  if (idx < 0) {
    return root;
  }
  if (root.array.length === 1) {
    return void 0;
  }
  return {
    type: COLLISION_NODE,
    hash: root.hash,
    array: spliceOut(root.array, idx)
  };
}
function forEach(root, fn) {
  if (root === void 0) {
    return;
  }
  const items = root.array;
  const size = items.length;
  for (let i = 0; i < size; i++) {
    const item = items[i];
    if (item === void 0) {
      continue;
    }
    if (item.type === ENTRY) {
      fn(item.v, item.k);
      continue;
    }
    forEach(item, fn);
  }
}
var Dict = class _Dict {
  /**
   * @template V
   * @param {Record<string,V>} o
   * @returns {Dict<string,V>}
   */
  static fromObject(o) {
    const keys2 = Object.keys(o);
    let m = _Dict.new();
    for (let i = 0; i < keys2.length; i++) {
      const k = keys2[i];
      m = m.set(k, o[k]);
    }
    return m;
  }
  /**
   * @template K,V
   * @param {Map<K,V>} o
   * @returns {Dict<K,V>}
   */
  static fromMap(o) {
    let m = _Dict.new();
    o.forEach((v, k) => {
      m = m.set(k, v);
    });
    return m;
  }
  static new() {
    return new _Dict(void 0, 0);
  }
  /**
   * @param {undefined | Node<K,V>} root
   * @param {number} size
   */
  constructor(root, size) {
    this.root = root;
    this.size = size;
  }
  /**
   * @template NotFound
   * @param {K} key
   * @param {NotFound} notFound
   * @returns {NotFound | V}
   */
  get(key, notFound) {
    if (this.root === void 0) {
      return notFound;
    }
    const found = find(this.root, 0, getHash(key), key);
    if (found === void 0) {
      return notFound;
    }
    return found.v;
  }
  /**
   * @param {K} key
   * @param {V} val
   * @returns {Dict<K,V>}
   */
  set(key, val) {
    const addedLeaf = { val: false };
    const root = this.root === void 0 ? EMPTY : this.root;
    const newRoot = assoc(root, 0, getHash(key), key, val, addedLeaf);
    if (newRoot === this.root) {
      return this;
    }
    return new _Dict(newRoot, addedLeaf.val ? this.size + 1 : this.size);
  }
  /**
   * @param {K} key
   * @returns {Dict<K,V>}
   */
  delete(key) {
    if (this.root === void 0) {
      return this;
    }
    const newRoot = without(this.root, 0, getHash(key), key);
    if (newRoot === this.root) {
      return this;
    }
    if (newRoot === void 0) {
      return _Dict.new();
    }
    return new _Dict(newRoot, this.size - 1);
  }
  /**
   * @param {K} key
   * @returns {boolean}
   */
  has(key) {
    if (this.root === void 0) {
      return false;
    }
    return find(this.root, 0, getHash(key), key) !== void 0;
  }
  /**
   * @returns {[K,V][]}
   */
  entries() {
    if (this.root === void 0) {
      return [];
    }
    const result = [];
    this.forEach((v, k) => result.push([k, v]));
    return result;
  }
  /**
   *
   * @param {(val:V,key:K)=>void} fn
   */
  forEach(fn) {
    forEach(this.root, fn);
  }
  hashCode() {
    let h = 0;
    this.forEach((v, k) => {
      h = h + hashMerge(getHash(v), getHash(k)) | 0;
    });
    return h;
  }
  /**
   * @param {unknown} o
   * @returns {boolean}
   */
  equals(o) {
    if (!(o instanceof _Dict) || this.size !== o.size) {
      return false;
    }
    try {
      this.forEach((v, k) => {
        if (!isEqual(o.get(k, !v), v)) {
          throw unequalDictSymbol;
        }
      });
      return true;
    } catch (e) {
      if (e === unequalDictSymbol) {
        return false;
      }
      throw e;
    }
  }
};
var unequalDictSymbol = Symbol();

// build/dev/javascript/gleam_stdlib/gleam_stdlib.mjs
var Nil = void 0;
var NOT_FOUND = {};
function identity(x) {
  return x;
}
function to_string(term) {
  return term.toString();
}
function float_to_string(float4) {
  const string5 = float4.toString().replace("+", "");
  if (string5.indexOf(".") >= 0) {
    return string5;
  } else {
    const index4 = string5.indexOf("e");
    if (index4 >= 0) {
      return string5.slice(0, index4) + ".0" + string5.slice(index4);
    } else {
      return string5 + ".0";
    }
  }
}
var segmenter = void 0;
function graphemes_iterator(string5) {
  if (globalThis.Intl && Intl.Segmenter) {
    segmenter ||= new Intl.Segmenter();
    return segmenter.segment(string5)[Symbol.iterator]();
  }
}
function pop_grapheme(string5) {
  let first2;
  const iterator = graphemes_iterator(string5);
  if (iterator) {
    first2 = iterator.next().value?.segment;
  } else {
    first2 = string5.match(/./su)?.[0];
  }
  if (first2) {
    return new Ok([first2, string5.slice(first2.length)]);
  } else {
    return new Error(Nil);
  }
}
function concat(xs) {
  let result = "";
  for (const x of xs) {
    result = result + x;
  }
  return result;
}
var unicode_whitespaces = [
  " ",
  // Space
  "	",
  // Horizontal tab
  "\n",
  // Line feed
  "\v",
  // Vertical tab
  "\f",
  // Form feed
  "\r",
  // Carriage return
  "\x85",
  // Next line
  "\u2028",
  // Line separator
  "\u2029"
  // Paragraph separator
].join("");
var trim_start_regex = new RegExp(`^[${unicode_whitespaces}]*`);
var trim_end_regex = new RegExp(`[${unicode_whitespaces}]*$`);
function new_map() {
  return Dict.new();
}
function map_to_list(map6) {
  return List.fromArray(map6.entries());
}
function map_get(map6, key) {
  const value3 = map6.get(key, NOT_FOUND);
  if (value3 === NOT_FOUND) {
    return new Error(Nil);
  }
  return new Ok(value3);
}
function map_insert(key, value3, map6) {
  return map6.set(key, value3);
}
function classify_dynamic(data) {
  if (typeof data === "string") {
    return "String";
  } else if (typeof data === "boolean") {
    return "Bool";
  } else if (data instanceof Result) {
    return "Result";
  } else if (data instanceof List) {
    return "List";
  } else if (data instanceof BitArray) {
    return "BitArray";
  } else if (data instanceof Dict) {
    return "Dict";
  } else if (Number.isInteger(data)) {
    return "Int";
  } else if (Array.isArray(data)) {
    return `Tuple of ${data.length} elements`;
  } else if (typeof data === "number") {
    return "Float";
  } else if (data === null) {
    return "Null";
  } else if (data === void 0) {
    return "Nil";
  } else {
    const type = typeof data;
    return type.charAt(0).toUpperCase() + type.slice(1);
  }
}
function decoder_error(expected, got) {
  return decoder_error_no_classify(expected, classify_dynamic(got));
}
function decoder_error_no_classify(expected, got) {
  return new Error(
    List.fromArray([new DecodeError(expected, got, List.fromArray([]))])
  );
}
function decode_string(data) {
  return typeof data === "string" ? new Ok(data) : decoder_error("String", data);
}
function decode_int(data) {
  return Number.isInteger(data) ? new Ok(data) : decoder_error("Int", data);
}
function decode_field(value3, name2) {
  const not_a_map_error = () => decoder_error("Dict", value3);
  if (value3 instanceof Dict || value3 instanceof WeakMap || value3 instanceof Map) {
    const entry = map_get(value3, name2);
    return new Ok(entry.isOk() ? new Some(entry[0]) : new None());
  } else if (value3 === null) {
    return not_a_map_error();
  } else if (Object.getPrototypeOf(value3) == Object.prototype) {
    return try_get_field(value3, name2, () => new Ok(new None()));
  } else {
    return try_get_field(value3, name2, not_a_map_error);
  }
}
function try_get_field(value3, field3, or_else) {
  try {
    return field3 in value3 ? new Ok(new Some(value3[field3])) : or_else();
  } catch {
    return or_else();
  }
}
function inspect(v) {
  const t = typeof v;
  if (v === true)
    return "True";
  if (v === false)
    return "False";
  if (v === null)
    return "//js(null)";
  if (v === void 0)
    return "Nil";
  if (t === "string")
    return inspectString(v);
  if (t === "bigint" || Number.isInteger(v))
    return v.toString();
  if (t === "number")
    return float_to_string(v);
  if (Array.isArray(v))
    return `#(${v.map(inspect).join(", ")})`;
  if (v instanceof List)
    return inspectList(v);
  if (v instanceof UtfCodepoint)
    return inspectUtfCodepoint(v);
  if (v instanceof BitArray)
    return inspectBitArray(v);
  if (v instanceof CustomType)
    return inspectCustomType(v);
  if (v instanceof Dict)
    return inspectDict(v);
  if (v instanceof Set)
    return `//js(Set(${[...v].map(inspect).join(", ")}))`;
  if (v instanceof RegExp)
    return `//js(${v})`;
  if (v instanceof Date)
    return `//js(Date("${v.toISOString()}"))`;
  if (v instanceof Function) {
    const args = [];
    for (const i of Array(v.length).keys())
      args.push(String.fromCharCode(i + 97));
    return `//fn(${args.join(", ")}) { ... }`;
  }
  return inspectObject(v);
}
function inspectString(str) {
  let new_str = '"';
  for (let i = 0; i < str.length; i++) {
    let char = str[i];
    switch (char) {
      case "\n":
        new_str += "\\n";
        break;
      case "\r":
        new_str += "\\r";
        break;
      case "	":
        new_str += "\\t";
        break;
      case "\f":
        new_str += "\\f";
        break;
      case "\\":
        new_str += "\\\\";
        break;
      case '"':
        new_str += '\\"';
        break;
      default:
        if (char < " " || char > "~" && char < "\xA0") {
          new_str += "\\u{" + char.charCodeAt(0).toString(16).toUpperCase().padStart(4, "0") + "}";
        } else {
          new_str += char;
        }
    }
  }
  new_str += '"';
  return new_str;
}
function inspectDict(map6) {
  let body = "dict.from_list([";
  let first2 = true;
  map6.forEach((value3, key) => {
    if (!first2)
      body = body + ", ";
    body = body + "#(" + inspect(key) + ", " + inspect(value3) + ")";
    first2 = false;
  });
  return body + "])";
}
function inspectObject(v) {
  const name2 = Object.getPrototypeOf(v)?.constructor?.name || "Object";
  const props = [];
  for (const k of Object.keys(v)) {
    props.push(`${inspect(k)}: ${inspect(v[k])}`);
  }
  const body = props.length ? " " + props.join(", ") + " " : "";
  const head = name2 === "Object" ? "" : name2 + " ";
  return `//js(${head}{${body}})`;
}
function inspectCustomType(record) {
  const props = Object.keys(record).map((label) => {
    const value3 = inspect(record[label]);
    return isNaN(parseInt(label)) ? `${label}: ${value3}` : value3;
  }).join(", ");
  return props ? `${record.constructor.name}(${props})` : record.constructor.name;
}
function inspectList(list3) {
  return `[${list3.toArray().map(inspect).join(", ")}]`;
}
function inspectBitArray(bits) {
  return `<<${Array.from(bits.buffer).join(", ")}>>`;
}
function inspectUtfCodepoint(codepoint2) {
  return `//utfcodepoint(${String.fromCodePoint(codepoint2.value)})`;
}

// build/dev/javascript/gleam_stdlib/gleam/dict.mjs
function insert(dict2, key, value3) {
  return map_insert(key, value3, dict2);
}
function from_list_loop(loop$list, loop$initial) {
  while (true) {
    let list3 = loop$list;
    let initial = loop$initial;
    if (list3.hasLength(0)) {
      return initial;
    } else {
      let key = list3.head[0];
      let value3 = list3.head[1];
      let rest = list3.tail;
      loop$list = rest;
      loop$initial = insert(initial, key, value3);
    }
  }
}
function from_list(list3) {
  return from_list_loop(list3, new_map());
}
function reverse_and_concat(loop$remaining, loop$accumulator) {
  while (true) {
    let remaining = loop$remaining;
    let accumulator = loop$accumulator;
    if (remaining.hasLength(0)) {
      return accumulator;
    } else {
      let first2 = remaining.head;
      let rest = remaining.tail;
      loop$remaining = rest;
      loop$accumulator = prepend(first2, accumulator);
    }
  }
}
function do_keys_loop(loop$list, loop$acc) {
  while (true) {
    let list3 = loop$list;
    let acc = loop$acc;
    if (list3.hasLength(0)) {
      return reverse_and_concat(acc, toList([]));
    } else {
      let key = list3.head[0];
      let rest = list3.tail;
      loop$list = rest;
      loop$acc = prepend(key, acc);
    }
  }
}
function keys(dict2) {
  return do_keys_loop(map_to_list(dict2), toList([]));
}

// build/dev/javascript/gleam_stdlib/gleam/list.mjs
function reverse_and_prepend(loop$prefix, loop$suffix) {
  while (true) {
    let prefix = loop$prefix;
    let suffix = loop$suffix;
    if (prefix.hasLength(0)) {
      return suffix;
    } else {
      let first$1 = prefix.head;
      let rest$1 = prefix.tail;
      loop$prefix = rest$1;
      loop$suffix = prepend(first$1, suffix);
    }
  }
}
function reverse(list3) {
  return reverse_and_prepend(list3, toList([]));
}
function map_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list3 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list3.hasLength(0)) {
      return reverse(acc);
    } else {
      let first$1 = list3.head;
      let rest$1 = list3.tail;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = prepend(fun(first$1), acc);
    }
  }
}
function map2(list3, fun) {
  return map_loop(list3, fun, toList([]));
}
function append_loop(loop$first, loop$second) {
  while (true) {
    let first2 = loop$first;
    let second = loop$second;
    if (first2.hasLength(0)) {
      return second;
    } else {
      let first$1 = first2.head;
      let rest$1 = first2.tail;
      loop$first = rest$1;
      loop$second = prepend(first$1, second);
    }
  }
}
function append(first2, second) {
  return append_loop(reverse(first2), second);
}
function fold(loop$list, loop$initial, loop$fun) {
  while (true) {
    let list3 = loop$list;
    let initial = loop$initial;
    let fun = loop$fun;
    if (list3.hasLength(0)) {
      return initial;
    } else {
      let first$1 = list3.head;
      let rest$1 = list3.tail;
      loop$list = rest$1;
      loop$initial = fun(initial, first$1);
      loop$fun = fun;
    }
  }
}
function index_fold_loop(loop$over, loop$acc, loop$with, loop$index) {
  while (true) {
    let over = loop$over;
    let acc = loop$acc;
    let with$ = loop$with;
    let index4 = loop$index;
    if (over.hasLength(0)) {
      return acc;
    } else {
      let first$1 = over.head;
      let rest$1 = over.tail;
      loop$over = rest$1;
      loop$acc = with$(acc, first$1, index4);
      loop$with = with$;
      loop$index = index4 + 1;
    }
  }
}
function index_fold(list3, initial, fun) {
  return index_fold_loop(list3, initial, fun, 0);
}

// build/dev/javascript/gleam_stdlib/gleam/string.mjs
function drop_start(loop$string, loop$num_graphemes) {
  while (true) {
    let string5 = loop$string;
    let num_graphemes = loop$num_graphemes;
    let $ = num_graphemes > 0;
    if (!$) {
      return string5;
    } else {
      let $1 = pop_grapheme(string5);
      if ($1.isOk()) {
        let string$1 = $1[0][1];
        loop$string = string$1;
        loop$num_graphemes = num_graphemes - 1;
      } else {
        return string5;
      }
    }
  }
}
function inspect2(term) {
  let _pipe = inspect(term);
  return identity(_pipe);
}

// build/dev/javascript/gleam_stdlib/gleam/result.mjs
function map3(result, fun) {
  if (result.isOk()) {
    let x = result[0];
    return new Ok(fun(x));
  } else {
    let e = result[0];
    return new Error(e);
  }
}
function map_error(result, fun) {
  if (result.isOk()) {
    let x = result[0];
    return new Ok(x);
  } else {
    let error = result[0];
    return new Error(fun(error));
  }
}
function try$(result, fun) {
  if (result.isOk()) {
    let x = result[0];
    return fun(x);
  } else {
    let e = result[0];
    return new Error(e);
  }
}
function then$(result, fun) {
  return try$(result, fun);
}
function unwrap(result, default$) {
  if (result.isOk()) {
    let v = result[0];
    return v;
  } else {
    return default$;
  }
}
function replace_error(result, error) {
  if (result.isOk()) {
    let x = result[0];
    return new Ok(x);
  } else {
    return new Error(error);
  }
}

// build/dev/javascript/gleam_stdlib/gleam/dynamic.mjs
var DecodeError = class extends CustomType {
  constructor(expected, found, path) {
    super();
    this.expected = expected;
    this.found = found;
    this.path = path;
  }
};
function map_errors(result, f) {
  return map_error(
    result,
    (_capture) => {
      return map2(_capture, f);
    }
  );
}
function string(data) {
  return decode_string(data);
}
function do_any(decoders) {
  return (data) => {
    if (decoders.hasLength(0)) {
      return new Error(
        toList([new DecodeError("another type", classify_dynamic(data), toList([]))])
      );
    } else {
      let decoder = decoders.head;
      let decoders$1 = decoders.tail;
      let $ = decoder(data);
      if ($.isOk()) {
        let decoded = $[0];
        return new Ok(decoded);
      } else {
        return do_any(decoders$1)(data);
      }
    }
  };
}
function push_path(error, name2) {
  let name$1 = identity(name2);
  let decoder = do_any(
    toList([
      decode_string,
      (x) => {
        return map3(decode_int(x), to_string);
      }
    ])
  );
  let name$2 = (() => {
    let $ = decoder(name$1);
    if ($.isOk()) {
      let name$22 = $[0];
      return name$22;
    } else {
      let _pipe = toList(["<", classify_dynamic(name$1), ">"]);
      let _pipe$1 = concat(_pipe);
      return identity(_pipe$1);
    }
  })();
  let _record = error;
  return new DecodeError(
    _record.expected,
    _record.found,
    prepend(name$2, error.path)
  );
}
function field(name2, inner_type) {
  return (value3) => {
    let missing_field_error = new DecodeError("field", "nothing", toList([]));
    return try$(
      decode_field(value3, name2),
      (maybe_inner) => {
        let _pipe = maybe_inner;
        let _pipe$1 = to_result(_pipe, toList([missing_field_error]));
        let _pipe$2 = try$(_pipe$1, inner_type);
        return map_errors(
          _pipe$2,
          (_capture) => {
            return push_path(_capture, name2);
          }
        );
      }
    );
  };
}

// build/dev/javascript/gleam_stdlib/gleam_stdlib_decode_ffi.mjs
function index2(data, key) {
  const int5 = Number.isInteger(key);
  if (data instanceof Dict || data instanceof WeakMap || data instanceof Map) {
    const token = {};
    const entry = data.get(key, token);
    if (entry === token)
      return new Ok(new None());
    return new Ok(new Some(entry));
  }
  if ((key === 0 || key === 1 || key === 2) && data instanceof List) {
    let i = 0;
    for (const value3 of data) {
      if (i === key)
        return new Ok(new Some(value3));
      i++;
    }
    return new Error("Indexable");
  }
  if (int5 && Array.isArray(data) || data && typeof data === "object" || data && Object.getPrototypeOf(data) === Object.prototype) {
    if (key in data)
      return new Ok(new Some(data[key]));
    return new Ok(new None());
  }
  return new Error(int5 ? "Indexable" : "Dict");
}
function list(data, decode2, pushPath, index4, emptyList) {
  if (!(data instanceof List || Array.isArray(data))) {
    let error = new DecodeError2("List", classify_dynamic(data), emptyList);
    return [emptyList, List.fromArray([error])];
  }
  const decoded = [];
  for (const element2 of data) {
    const layer = decode2(element2);
    const [out, errors] = layer;
    if (errors instanceof NonEmpty) {
      const [_, errors2] = pushPath(layer, index4.toString());
      return [emptyList, errors2];
    }
    decoded.push(out);
    index4++;
  }
  return [List.fromArray(decoded), emptyList];
}
function int(data) {
  if (Number.isInteger(data))
    return new Ok(data);
  return new Error(0);
}
function string2(data) {
  if (typeof data === "string")
    return new Ok(data);
  return new Error(0);
}
function is_null(data) {
  return data === null || data === void 0;
}

// build/dev/javascript/gleam_stdlib/gleam/dynamic/decode.mjs
var DecodeError2 = class extends CustomType {
  constructor(expected, found, path) {
    super();
    this.expected = expected;
    this.found = found;
    this.path = path;
  }
};
var Decoder = class extends CustomType {
  constructor(function$) {
    super();
    this.function = function$;
  }
};
function run(data, decoder) {
  let $ = decoder.function(data);
  let maybe_invalid_data = $[0];
  let errors = $[1];
  if (errors.hasLength(0)) {
    return new Ok(maybe_invalid_data);
  } else {
    return new Error(errors);
  }
}
function success(data) {
  return new Decoder((_) => {
    return [data, toList([])];
  });
}
function map4(decoder, transformer) {
  return new Decoder(
    (d) => {
      let $ = decoder.function(d);
      let data = $[0];
      let errors = $[1];
      return [transformer(data), errors];
    }
  );
}
function run_decoders(loop$data, loop$failure, loop$decoders) {
  while (true) {
    let data = loop$data;
    let failure = loop$failure;
    let decoders = loop$decoders;
    if (decoders.hasLength(0)) {
      return failure;
    } else {
      let decoder = decoders.head;
      let decoders$1 = decoders.tail;
      let $ = decoder.function(data);
      let layer = $;
      let errors = $[1];
      if (errors.hasLength(0)) {
        return layer;
      } else {
        loop$data = data;
        loop$failure = failure;
        loop$decoders = decoders$1;
      }
    }
  }
}
function one_of(first2, alternatives) {
  return new Decoder(
    (dynamic_data) => {
      let $ = first2.function(dynamic_data);
      let layer = $;
      let errors = $[1];
      if (errors.hasLength(0)) {
        return layer;
      } else {
        return run_decoders(dynamic_data, layer, alternatives);
      }
    }
  );
}
function optional(inner) {
  return new Decoder(
    (data) => {
      let $ = is_null(data);
      if ($) {
        return [new None(), toList([])];
      } else {
        let $1 = inner.function(data);
        let data$1 = $1[0];
        let errors = $1[1];
        return [new Some(data$1), errors];
      }
    }
  );
}
function decode_error(expected, found) {
  return toList([
    new DecodeError2(expected, classify_dynamic(found), toList([]))
  ]);
}
function run_dynamic_function(data, name2, f) {
  let $ = f(data);
  if ($.isOk()) {
    let data$1 = $[0];
    return [data$1, toList([])];
  } else {
    let zero = $[0];
    return [
      zero,
      toList([new DecodeError2(name2, classify_dynamic(data), toList([]))])
    ];
  }
}
function decode_bool2(data) {
  let $ = isEqual(identity(true), data);
  if ($) {
    return [true, toList([])];
  } else {
    let $1 = isEqual(identity(false), data);
    if ($1) {
      return [false, toList([])];
    } else {
      return [false, decode_error("Bool", data)];
    }
  }
}
function decode_int2(data) {
  return run_dynamic_function(data, "Int", int);
}
var bool = /* @__PURE__ */ new Decoder(decode_bool2);
var int2 = /* @__PURE__ */ new Decoder(decode_int2);
function decode_string2(data) {
  return run_dynamic_function(data, "String", string2);
}
var string3 = /* @__PURE__ */ new Decoder(decode_string2);
function list2(inner) {
  return new Decoder(
    (data) => {
      return list(
        data,
        inner.function,
        (p2, k) => {
          return push_path2(p2, toList([k]));
        },
        0,
        toList([])
      );
    }
  );
}
function push_path2(layer, path) {
  let decoder = one_of(
    string3,
    toList([
      (() => {
        let _pipe = int2;
        return map4(_pipe, to_string);
      })()
    ])
  );
  let path$1 = map2(
    path,
    (key) => {
      let key$1 = identity(key);
      let $ = run(key$1, decoder);
      if ($.isOk()) {
        let key$2 = $[0];
        return key$2;
      } else {
        return "<" + classify_dynamic(key$1) + ">";
      }
    }
  );
  let errors = map2(
    layer[1],
    (error) => {
      let _record = error;
      return new DecodeError2(
        _record.expected,
        _record.found,
        append(path$1, error.path)
      );
    }
  );
  return [layer[0], errors];
}
function index3(loop$path, loop$position, loop$inner, loop$data, loop$handle_miss) {
  while (true) {
    let path = loop$path;
    let position = loop$position;
    let inner = loop$inner;
    let data = loop$data;
    let handle_miss = loop$handle_miss;
    if (path.hasLength(0)) {
      let _pipe = inner(data);
      return push_path2(_pipe, reverse(position));
    } else {
      let key = path.head;
      let path$1 = path.tail;
      let $ = index2(data, key);
      if ($.isOk() && $[0] instanceof Some) {
        let data$1 = $[0][0];
        loop$path = path$1;
        loop$position = prepend(key, position);
        loop$inner = inner;
        loop$data = data$1;
        loop$handle_miss = handle_miss;
      } else if ($.isOk() && $[0] instanceof None) {
        return handle_miss(data, prepend(key, position));
      } else {
        let kind = $[0];
        let $1 = inner(data);
        let default$ = $1[0];
        let _pipe = [
          default$,
          toList([new DecodeError2(kind, classify_dynamic(data), toList([]))])
        ];
        return push_path2(_pipe, reverse(position));
      }
    }
  }
}
function subfield(field_path, field_decoder, next) {
  return new Decoder(
    (data) => {
      let $ = index3(
        field_path,
        toList([]),
        field_decoder.function,
        data,
        (data2, position) => {
          let $12 = field_decoder.function(data2);
          let default$ = $12[0];
          let _pipe = [
            default$,
            toList([new DecodeError2("Field", "Nothing", toList([]))])
          ];
          return push_path2(_pipe, reverse(position));
        }
      );
      let out = $[0];
      let errors1 = $[1];
      let $1 = next(out).function(data);
      let out$1 = $1[0];
      let errors2 = $1[1];
      return [out$1, append(errors1, errors2)];
    }
  );
}
function field2(field_name, field_decoder, next) {
  return subfield(toList([field_name]), field_decoder, next);
}

// build/dev/javascript/gleam_stdlib/gleam/bool.mjs
function lazy_guard(requirement, consequence, alternative) {
  if (requirement) {
    return consequence();
  } else {
    return alternative();
  }
}

// build/dev/javascript/gleam_json/gleam_json_ffi.mjs
function object(entries) {
  return Object.fromEntries(entries);
}
function identity2(x) {
  return x;
}
function do_null() {
  return null;
}
function decode(string5) {
  try {
    const result = JSON.parse(string5);
    return new Ok(result);
  } catch (err) {
    return new Error(getJsonDecodeError(err, string5));
  }
}
function getJsonDecodeError(stdErr, json) {
  if (isUnexpectedEndOfInput(stdErr))
    return new UnexpectedEndOfInput();
  return toUnexpectedByteError(stdErr, json);
}
function isUnexpectedEndOfInput(err) {
  const unexpectedEndOfInputRegex = /((unexpected (end|eof))|(end of data)|(unterminated string)|(json( parse error|\.parse)\: expected '(\:|\}|\])'))/i;
  return unexpectedEndOfInputRegex.test(err.message);
}
function toUnexpectedByteError(err, json) {
  let converters = [
    v8UnexpectedByteError,
    oldV8UnexpectedByteError,
    jsCoreUnexpectedByteError,
    spidermonkeyUnexpectedByteError
  ];
  for (let converter of converters) {
    let result = converter(err, json);
    if (result)
      return result;
  }
  return new UnexpectedByte("", 0);
}
function v8UnexpectedByteError(err) {
  const regex = /unexpected token '(.)', ".+" is not valid JSON/i;
  const match = regex.exec(err.message);
  if (!match)
    return null;
  const byte = toHex(match[1]);
  return new UnexpectedByte(byte, -1);
}
function oldV8UnexpectedByteError(err) {
  const regex = /unexpected token (.) in JSON at position (\d+)/i;
  const match = regex.exec(err.message);
  if (!match)
    return null;
  const byte = toHex(match[1]);
  const position = Number(match[2]);
  return new UnexpectedByte(byte, position);
}
function spidermonkeyUnexpectedByteError(err, json) {
  const regex = /(unexpected character|expected .*) at line (\d+) column (\d+)/i;
  const match = regex.exec(err.message);
  if (!match)
    return null;
  const line = Number(match[2]);
  const column = Number(match[3]);
  const position = getPositionFromMultiline(line, column, json);
  const byte = toHex(json[position]);
  return new UnexpectedByte(byte, position);
}
function jsCoreUnexpectedByteError(err) {
  const regex = /unexpected (identifier|token) "(.)"/i;
  const match = regex.exec(err.message);
  if (!match)
    return null;
  const byte = toHex(match[2]);
  return new UnexpectedByte(byte, 0);
}
function toHex(char) {
  return "0x" + char.charCodeAt(0).toString(16).toUpperCase();
}
function getPositionFromMultiline(line, column, string5) {
  if (line === 1)
    return column - 1;
  let currentLn = 1;
  let position = 0;
  string5.split("").find((char, idx) => {
    if (char === "\n")
      currentLn += 1;
    if (currentLn === line) {
      position = idx + column;
      return true;
    }
    return false;
  });
  return position;
}

// build/dev/javascript/gleam_json/gleam/json.mjs
var UnexpectedEndOfInput = class extends CustomType {
};
var UnexpectedByte = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UnableToDecode = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
function do_parse(json, decoder) {
  return then$(
    decode(json),
    (dynamic_value) => {
      let _pipe = run(dynamic_value, decoder);
      return map_error(
        _pipe,
        (var0) => {
          return new UnableToDecode(var0);
        }
      );
    }
  );
}
function parse(json, decoder) {
  return do_parse(json, decoder);
}
function string4(input2) {
  return identity2(input2);
}
function bool2(input2) {
  return identity2(input2);
}
function int3(input2) {
  return identity2(input2);
}
function null$() {
  return do_null();
}
function nullable(input2, inner_type) {
  if (input2 instanceof Some) {
    let value3 = input2[0];
    return inner_type(value3);
  } else {
    return null$();
  }
}
function object2(entries) {
  return object(entries);
}

// build/dev/javascript/lustre/lustre/effect.mjs
var Effect = class extends CustomType {
  constructor(all2) {
    super();
    this.all = all2;
  }
};
function custom(run2) {
  return new Effect(
    toList([
      (actions) => {
        return run2(actions.dispatch, actions.emit, actions.select, actions.root);
      }
    ])
  );
}
function event(name2, data) {
  return custom((_, emit3, _1, _2) => {
    return emit3(name2, data);
  });
}
function none() {
  return new Effect(toList([]));
}

// build/dev/javascript/lustre/lustre/internals/vdom.mjs
var Text = class extends CustomType {
  constructor(content) {
    super();
    this.content = content;
  }
};
var Element = class extends CustomType {
  constructor(key, namespace, tag, attrs, children2, self_closing, void$) {
    super();
    this.key = key;
    this.namespace = namespace;
    this.tag = tag;
    this.attrs = attrs;
    this.children = children2;
    this.self_closing = self_closing;
    this.void = void$;
  }
};
var Map2 = class extends CustomType {
  constructor(subtree) {
    super();
    this.subtree = subtree;
  }
};
var Attribute = class extends CustomType {
  constructor(x0, x1, as_property) {
    super();
    this[0] = x0;
    this[1] = x1;
    this.as_property = as_property;
  }
};
var Event = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
function attribute_to_event_handler(attribute2) {
  if (attribute2 instanceof Attribute) {
    return new Error(void 0);
  } else {
    let name2 = attribute2[0];
    let handler = attribute2[1];
    let name$1 = drop_start(name2, 2);
    return new Ok([name$1, handler]);
  }
}
function do_element_list_handlers(elements2, handlers2, key) {
  return index_fold(
    elements2,
    handlers2,
    (handlers3, element2, index4) => {
      let key$1 = key + "-" + to_string(index4);
      return do_handlers(element2, handlers3, key$1);
    }
  );
}
function do_handlers(loop$element, loop$handlers, loop$key) {
  while (true) {
    let element2 = loop$element;
    let handlers2 = loop$handlers;
    let key = loop$key;
    if (element2 instanceof Text) {
      return handlers2;
    } else if (element2 instanceof Map2) {
      let subtree = element2.subtree;
      loop$element = subtree();
      loop$handlers = handlers2;
      loop$key = key;
    } else {
      let attrs = element2.attrs;
      let children2 = element2.children;
      let handlers$1 = fold(
        attrs,
        handlers2,
        (handlers3, attr) => {
          let $ = attribute_to_event_handler(attr);
          if ($.isOk()) {
            let name2 = $[0][0];
            let handler = $[0][1];
            return insert(handlers3, key + "-" + name2, handler);
          } else {
            return handlers3;
          }
        }
      );
      return do_element_list_handlers(children2, handlers$1, key);
    }
  }
}
function handlers(element2) {
  return do_handlers(element2, new_map(), "0");
}

// build/dev/javascript/lustre/lustre/attribute.mjs
function attribute(name2, value3) {
  return new Attribute(name2, identity(value3), false);
}
function on(name2, handler) {
  return new Event("on" + name2, handler);
}
function style(properties) {
  return attribute(
    "style",
    fold(
      properties,
      "",
      (styles, _use1) => {
        let name$1 = _use1[0];
        let value$1 = _use1[1];
        return styles + name$1 + ":" + value$1 + ";";
      }
    )
  );
}
function class$(name2) {
  return attribute("class", name2);
}
function value(val) {
  return attribute("value", val);
}

// build/dev/javascript/lustre/lustre/element.mjs
function element(tag, attrs, children2) {
  if (tag === "area") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "base") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "br") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "col") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "embed") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "hr") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "img") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "input") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "link") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "meta") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "param") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "source") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "track") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "wbr") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else {
    return new Element("", "", tag, attrs, children2, false, false);
  }
}
function text(content) {
  return new Text(content);
}
function fragment(elements2) {
  return element(
    "lustre-fragment",
    toList([style(toList([["display", "contents"]]))]),
    elements2
  );
}

// build/dev/javascript/gleam_stdlib/gleam/set.mjs
var Set2 = class extends CustomType {
  constructor(dict2) {
    super();
    this.dict = dict2;
  }
};
function new$2() {
  return new Set2(new_map());
}

// build/dev/javascript/lustre/lustre/internals/patch.mjs
var Diff = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Emit = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Init = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
function is_empty_element_diff(diff2) {
  return isEqual(diff2.created, new_map()) && isEqual(
    diff2.removed,
    new$2()
  ) && isEqual(diff2.updated, new_map());
}

// build/dev/javascript/lustre/lustre/internals/runtime.mjs
var Attrs = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Batch = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Debug = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Dispatch = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Emit2 = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Event2 = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Shutdown = class extends CustomType {
};
var Subscribe = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Unsubscribe = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var ForceModel = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};

// build/dev/javascript/lustre/lustre.mjs
var App = class extends CustomType {
  constructor(init3, update2, view2, on_attribute_change) {
    super();
    this.init = init3;
    this.update = update2;
    this.view = view2;
    this.on_attribute_change = on_attribute_change;
  }
};
var BadComponentName = class extends CustomType {
  constructor(name2) {
    super();
    this.name = name2;
  }
};
var ComponentAlreadyRegistered = class extends CustomType {
  constructor(name2) {
    super();
    this.name = name2;
  }
};
var ElementNotFound = class extends CustomType {
  constructor(selector) {
    super();
    this.selector = selector;
  }
};
var NotABrowser = class extends CustomType {
};
function component(init3, update2, view2, on_attribute_change) {
  return new App(init3, update2, view2, new Some(on_attribute_change));
}

// build/dev/javascript/lustre/vdom.ffi.mjs
if (globalThis.customElements && !globalThis.customElements.get("lustre-fragment")) {
  globalThis.customElements.define(
    "lustre-fragment",
    class LustreFragment extends HTMLElement {
      constructor() {
        super();
      }
    }
  );
}
function morph(prev, next, dispatch) {
  let out;
  let stack = [{ prev, next, parent: prev.parentNode }];
  while (stack.length) {
    let { prev: prev2, next: next2, parent } = stack.pop();
    while (next2.subtree !== void 0)
      next2 = next2.subtree();
    if (next2.content !== void 0) {
      if (!prev2) {
        const created = document.createTextNode(next2.content);
        parent.appendChild(created);
        out ??= created;
      } else if (prev2.nodeType === Node.TEXT_NODE) {
        if (prev2.textContent !== next2.content)
          prev2.textContent = next2.content;
        out ??= prev2;
      } else {
        const created = document.createTextNode(next2.content);
        parent.replaceChild(created, prev2);
        out ??= created;
      }
    } else if (next2.tag !== void 0) {
      const created = createElementNode({
        prev: prev2,
        next: next2,
        dispatch,
        stack
      });
      if (!prev2) {
        parent.appendChild(created);
      } else if (prev2 !== created) {
        parent.replaceChild(created, prev2);
      }
      out ??= created;
    }
  }
  return out;
}
function createElementNode({ prev, next, dispatch, stack }) {
  const namespace = next.namespace || "http://www.w3.org/1999/xhtml";
  const canMorph = prev && prev.nodeType === Node.ELEMENT_NODE && prev.localName === next.tag && prev.namespaceURI === (next.namespace || "http://www.w3.org/1999/xhtml");
  const el = canMorph ? prev : namespace ? document.createElementNS(namespace, next.tag) : document.createElement(next.tag);
  let handlersForEl;
  if (!registeredHandlers.has(el)) {
    const emptyHandlers = /* @__PURE__ */ new Map();
    registeredHandlers.set(el, emptyHandlers);
    handlersForEl = emptyHandlers;
  } else {
    handlersForEl = registeredHandlers.get(el);
  }
  const prevHandlers = canMorph ? new Set(handlersForEl.keys()) : null;
  const prevAttributes = canMorph ? new Set(Array.from(prev.attributes, (a) => a.name)) : null;
  let className = null;
  let style3 = null;
  let innerHTML = null;
  if (canMorph && next.tag === "textarea") {
    const innertText = next.children[Symbol.iterator]().next().value?.content;
    if (innertText !== void 0)
      el.value = innertText;
  }
  const delegated = [];
  for (const attr of next.attrs) {
    const name2 = attr[0];
    const value3 = attr[1];
    if (attr.as_property) {
      if (el[name2] !== value3)
        el[name2] = value3;
      if (canMorph)
        prevAttributes.delete(name2);
    } else if (name2.startsWith("on")) {
      const eventName = name2.slice(2);
      const callback = dispatch(value3, eventName === "input");
      if (!handlersForEl.has(eventName)) {
        el.addEventListener(eventName, lustreGenericEventHandler);
      }
      handlersForEl.set(eventName, callback);
      if (canMorph)
        prevHandlers.delete(eventName);
    } else if (name2.startsWith("data-lustre-on-")) {
      const eventName = name2.slice(15);
      const callback = dispatch(lustreServerEventHandler);
      if (!handlersForEl.has(eventName)) {
        el.addEventListener(eventName, lustreGenericEventHandler);
      }
      handlersForEl.set(eventName, callback);
      el.setAttribute(name2, value3);
      if (canMorph) {
        prevHandlers.delete(eventName);
        prevAttributes.delete(name2);
      }
    } else if (name2.startsWith("delegate:data-") || name2.startsWith("delegate:aria-")) {
      el.setAttribute(name2, value3);
      delegated.push([name2.slice(10), value3]);
    } else if (name2 === "class") {
      className = className === null ? value3 : className + " " + value3;
    } else if (name2 === "style") {
      style3 = style3 === null ? value3 : style3 + value3;
    } else if (name2 === "dangerous-unescaped-html") {
      innerHTML = value3;
    } else {
      if (el.getAttribute(name2) !== value3)
        el.setAttribute(name2, value3);
      if (name2 === "value" || name2 === "selected")
        el[name2] = value3;
      if (canMorph)
        prevAttributes.delete(name2);
    }
  }
  if (className !== null) {
    el.setAttribute("class", className);
    if (canMorph)
      prevAttributes.delete("class");
  }
  if (style3 !== null) {
    el.setAttribute("style", style3);
    if (canMorph)
      prevAttributes.delete("style");
  }
  if (canMorph) {
    for (const attr of prevAttributes) {
      el.removeAttribute(attr);
    }
    for (const eventName of prevHandlers) {
      handlersForEl.delete(eventName);
      el.removeEventListener(eventName, lustreGenericEventHandler);
    }
  }
  if (next.tag === "slot") {
    window.queueMicrotask(() => {
      for (const child of el.assignedElements()) {
        for (const [name2, value3] of delegated) {
          if (!child.hasAttribute(name2)) {
            child.setAttribute(name2, value3);
          }
        }
      }
    });
  }
  if (next.key !== void 0 && next.key !== "") {
    el.setAttribute("data-lustre-key", next.key);
  } else if (innerHTML !== null) {
    el.innerHTML = innerHTML;
    return el;
  }
  let prevChild = el.firstChild;
  let seenKeys = null;
  let keyedChildren = null;
  let incomingKeyedChildren = null;
  let firstChild = children(next).next().value;
  if (canMorph && firstChild !== void 0 && // Explicit checks are more verbose but truthy checks force a bunch of comparisons
  // we don't care about: it's never gonna be a number etc.
  firstChild.key !== void 0 && firstChild.key !== "") {
    seenKeys = /* @__PURE__ */ new Set();
    keyedChildren = getKeyedChildren(prev);
    incomingKeyedChildren = getKeyedChildren(next);
    for (const child of children(next)) {
      prevChild = diffKeyedChild(
        prevChild,
        child,
        el,
        stack,
        incomingKeyedChildren,
        keyedChildren,
        seenKeys
      );
    }
  } else {
    for (const child of children(next)) {
      stack.unshift({ prev: prevChild, next: child, parent: el });
      prevChild = prevChild?.nextSibling;
    }
  }
  while (prevChild) {
    const next2 = prevChild.nextSibling;
    el.removeChild(prevChild);
    prevChild = next2;
  }
  return el;
}
var registeredHandlers = /* @__PURE__ */ new WeakMap();
function lustreGenericEventHandler(event2) {
  const target = event2.currentTarget;
  if (!registeredHandlers.has(target)) {
    target.removeEventListener(event2.type, lustreGenericEventHandler);
    return;
  }
  const handlersForEventTarget = registeredHandlers.get(target);
  if (!handlersForEventTarget.has(event2.type)) {
    target.removeEventListener(event2.type, lustreGenericEventHandler);
    return;
  }
  handlersForEventTarget.get(event2.type)(event2);
}
function lustreServerEventHandler(event2) {
  const el = event2.currentTarget;
  const tag = el.getAttribute(`data-lustre-on-${event2.type}`);
  const data = JSON.parse(el.getAttribute("data-lustre-data") || "{}");
  const include = JSON.parse(el.getAttribute("data-lustre-include") || "[]");
  switch (event2.type) {
    case "input":
    case "change":
      include.push("target.value");
      break;
  }
  return {
    tag,
    data: include.reduce(
      (data2, property) => {
        const path = property.split(".");
        for (let i = 0, o = data2, e = event2; i < path.length; i++) {
          if (i === path.length - 1) {
            o[path[i]] = e[path[i]];
          } else {
            o[path[i]] ??= {};
            e = e[path[i]];
            o = o[path[i]];
          }
        }
        return data2;
      },
      { data }
    )
  };
}
function getKeyedChildren(el) {
  const keyedChildren = /* @__PURE__ */ new Map();
  if (el) {
    for (const child of children(el)) {
      const key = child?.key || child?.getAttribute?.("data-lustre-key");
      if (key)
        keyedChildren.set(key, child);
    }
  }
  return keyedChildren;
}
function diffKeyedChild(prevChild, child, el, stack, incomingKeyedChildren, keyedChildren, seenKeys) {
  while (prevChild && !incomingKeyedChildren.has(prevChild.getAttribute("data-lustre-key"))) {
    const nextChild = prevChild.nextSibling;
    el.removeChild(prevChild);
    prevChild = nextChild;
  }
  if (keyedChildren.size === 0) {
    stack.unshift({ prev: prevChild, next: child, parent: el });
    prevChild = prevChild?.nextSibling;
    return prevChild;
  }
  if (seenKeys.has(child.key)) {
    console.warn(`Duplicate key found in Lustre vnode: ${child.key}`);
    stack.unshift({ prev: null, next: child, parent: el });
    return prevChild;
  }
  seenKeys.add(child.key);
  const keyedChild = keyedChildren.get(child.key);
  if (!keyedChild && !prevChild) {
    stack.unshift({ prev: null, next: child, parent: el });
    return prevChild;
  }
  if (!keyedChild && prevChild !== null) {
    const placeholder = document.createTextNode("");
    el.insertBefore(placeholder, prevChild);
    stack.unshift({ prev: placeholder, next: child, parent: el });
    return prevChild;
  }
  if (!keyedChild || keyedChild === prevChild) {
    stack.unshift({ prev: prevChild, next: child, parent: el });
    prevChild = prevChild?.nextSibling;
    return prevChild;
  }
  el.insertBefore(keyedChild, prevChild);
  stack.unshift({ prev: keyedChild, next: child, parent: el });
  return prevChild;
}
function* children(element2) {
  for (const child of element2.children) {
    yield* forceChild(child);
  }
}
function* forceChild(element2) {
  if (element2.subtree !== void 0) {
    yield* forceChild(element2.subtree());
  } else {
    yield element2;
  }
}

// build/dev/javascript/lustre/lustre.ffi.mjs
var LustreClientApplication = class _LustreClientApplication {
  /**
   * @template Flags
   *
   * @param {object} app
   * @param {(flags: Flags) => [Model, Lustre.Effect<Msg>]} app.init
   * @param {(msg: Msg, model: Model) => [Model, Lustre.Effect<Msg>]} app.update
   * @param {(model: Model) => Lustre.Element<Msg>} app.view
   * @param {string | HTMLElement} selector
   * @param {Flags} flags
   *
   * @returns {Gleam.Ok<(action: Lustre.Action<Lustre.Client, Msg>>) => void>}
   */
  static start({ init: init3, update: update2, view: view2 }, selector, flags) {
    if (!is_browser())
      return new Error(new NotABrowser());
    const root = selector instanceof HTMLElement ? selector : document.querySelector(selector);
    if (!root)
      return new Error(new ElementNotFound(selector));
    const app = new _LustreClientApplication(root, init3(flags), update2, view2);
    return new Ok((action) => app.send(action));
  }
  /**
   * @param {Element} root
   * @param {[Model, Lustre.Effect<Msg>]} init
   * @param {(model: Model, msg: Msg) => [Model, Lustre.Effect<Msg>]} update
   * @param {(model: Model) => Lustre.Element<Msg>} view
   *
   * @returns {LustreClientApplication}
   */
  constructor(root, [init3, effects], update2, view2) {
    this.root = root;
    this.#model = init3;
    this.#update = update2;
    this.#view = view2;
    this.#tickScheduled = window.setTimeout(
      () => this.#tick(effects.all.toArray(), true),
      0
    );
  }
  /** @type {Element} */
  root;
  /**
   * @param {Lustre.Action<Lustre.Client, Msg>} action
   *
   * @returns {void}
   */
  send(action) {
    if (action instanceof Debug) {
      if (action[0] instanceof ForceModel) {
        this.#tickScheduled = window.clearTimeout(this.#tickScheduled);
        this.#queue = [];
        this.#model = action[0][0];
        const vdom = this.#view(this.#model);
        const dispatch = (handler, immediate = false) => (event2) => {
          const result = handler(event2);
          if (result instanceof Ok) {
            this.send(new Dispatch(result[0], immediate));
          }
        };
        const prev = this.root.firstChild ?? this.root.appendChild(document.createTextNode(""));
        morph(prev, vdom, dispatch);
      }
    } else if (action instanceof Dispatch) {
      const msg = action[0];
      const immediate = action[1] ?? false;
      this.#queue.push(msg);
      if (immediate) {
        this.#tickScheduled = window.clearTimeout(this.#tickScheduled);
        this.#tick();
      } else if (!this.#tickScheduled) {
        this.#tickScheduled = window.setTimeout(() => this.#tick());
      }
    } else if (action instanceof Emit2) {
      const event2 = action[0];
      const data = action[1];
      this.root.dispatchEvent(
        new CustomEvent(event2, {
          detail: data,
          bubbles: true,
          composed: true
        })
      );
    } else if (action instanceof Shutdown) {
      this.#tickScheduled = window.clearTimeout(this.#tickScheduled);
      this.#model = null;
      this.#update = null;
      this.#view = null;
      this.#queue = null;
      while (this.root.firstChild) {
        this.root.firstChild.remove();
      }
    }
  }
  /** @type {Model} */
  #model;
  /** @type {(model: Model, msg: Msg) => [Model, Lustre.Effect<Msg>]} */
  #update;
  /** @type {(model: Model) => Lustre.Element<Msg>} */
  #view;
  /** @type {Array<Msg>} */
  #queue = [];
  /** @type {number | undefined} */
  #tickScheduled;
  /**
   * @param {Lustre.Effect<Msg>[]} effects
   */
  #tick(effects = []) {
    this.#tickScheduled = void 0;
    this.#flush(effects);
    const vdom = this.#view(this.#model);
    const dispatch = (handler, immediate = false) => (event2) => {
      const result = handler(event2);
      if (result instanceof Ok) {
        this.send(new Dispatch(result[0], immediate));
      }
    };
    const prev = this.root.firstChild ?? this.root.appendChild(document.createTextNode(""));
    morph(prev, vdom, dispatch);
  }
  #flush(effects = []) {
    while (this.#queue.length > 0) {
      const msg = this.#queue.shift();
      const [next, effect] = this.#update(this.#model, msg);
      effects = effects.concat(effect.all.toArray());
      this.#model = next;
    }
    while (effects.length > 0) {
      const effect = effects.shift();
      const dispatch = (msg) => this.send(new Dispatch(msg));
      const emit3 = (event2, data) => this.root.dispatchEvent(
        new CustomEvent(event2, {
          detail: data,
          bubbles: true,
          composed: true
        })
      );
      const select = () => {
      };
      const root = this.root;
      effect({ dispatch, emit: emit3, select, root });
    }
    if (this.#queue.length > 0) {
      this.#flush(effects);
    }
  }
};
var start = LustreClientApplication.start;
var make_lustre_client_component = ({ init: init3, update: update2, view: view2, on_attribute_change }, name2) => {
  if (!is_browser())
    return new Error(new NotABrowser());
  if (!name2.includes("-"))
    return new Error(new BadComponentName(name2));
  if (window.customElements.get(name2)) {
    return new Error(new ComponentAlreadyRegistered(name2));
  }
  const [model, effects] = init3(void 0);
  const hasAttributes = on_attribute_change instanceof Some;
  const component3 = class LustreClientComponent extends HTMLElement {
    /**
     * @returns {string[]}
     */
    static get observedAttributes() {
      if (hasAttributes) {
        return on_attribute_change[0].entries().map(([name3]) => name3);
      } else {
        return [];
      }
    }
    /**
     * @returns {LustreClientComponent}
     */
    constructor() {
      super();
      this.attachShadow({ mode: "open" });
      this.internals = this.attachInternals();
      if (hasAttributes) {
        on_attribute_change[0].forEach((decoder, name3) => {
          const key = `__mirrored__${name3}`;
          Object.defineProperty(this, name3, {
            get() {
              return this[key];
            },
            set(value3) {
              const prev = this[key];
              if (this.#connected && isEqual(prev, value3))
                return;
              this[key] = value3;
              const decoded = decoder(value3);
              if (decoded instanceof Error)
                return;
              this.#queue.push(decoded[0]);
              if (this.#connected && !this.#tickScheduled) {
                this.#tickScheduled = window.requestAnimationFrame(
                  () => this.#tick()
                );
              }
            }
          });
        });
      }
    }
    /**
     *
     */
    connectedCallback() {
      this.#adoptStyleSheets().finally(() => {
        this.#tick(effects.all.toArray(), true);
        this.#connected = true;
      });
    }
    /**
     * @param {string} key
     * @param {string} prev
     * @param {string} next
     */
    attributeChangedCallback(key, prev, next) {
      if (prev !== next)
        this[key] = next;
    }
    /**
     *
     */
    disconnectedCallback() {
      this.#model = null;
      this.#queue = [];
      this.#tickScheduled = window.cancelAnimationFrame(this.#tickScheduled);
      this.#connected = false;
    }
    /**
     * @param {Lustre.Action<Msg, Lustre.ClientSpa>} action
     */
    send(action) {
      if (action instanceof Debug) {
        if (action[0] instanceof ForceModel) {
          this.#tickScheduled = window.cancelAnimationFrame(
            this.#tickScheduled
          );
          this.#queue = [];
          this.#model = action[0][0];
          const vdom = view2(this.#model);
          const dispatch = (handler, immediate = false) => (event2) => {
            const result = handler(event2);
            if (result instanceof Ok) {
              this.send(new Dispatch(result[0], immediate));
            }
          };
          const prev = this.shadowRoot.childNodes[this.#adoptedStyleElements.length] ?? this.shadowRoot.appendChild(document.createTextNode(""));
          morph(prev, vdom, dispatch);
        }
      } else if (action instanceof Dispatch) {
        const msg = action[0];
        const immediate = action[1] ?? false;
        this.#queue.push(msg);
        if (immediate) {
          this.#tickScheduled = window.cancelAnimationFrame(
            this.#tickScheduled
          );
          this.#tick();
        } else if (!this.#tickScheduled) {
          this.#tickScheduled = window.requestAnimationFrame(
            () => this.#tick()
          );
        }
      } else if (action instanceof Emit2) {
        const event2 = action[0];
        const data = action[1];
        this.dispatchEvent(
          new CustomEvent(event2, {
            detail: data,
            bubbles: true,
            composed: true
          })
        );
      }
    }
    /** @type {Element[]} */
    #adoptedStyleElements = [];
    /** @type {Model} */
    #model = model;
    /** @type {Array<Msg>} */
    #queue = [];
    /** @type {number | undefined} */
    #tickScheduled;
    /** @type {boolean} */
    #connected = true;
    #tick(effects2 = []) {
      if (!this.#connected)
        return;
      this.#tickScheduled = void 0;
      this.#flush(effects2);
      const vdom = view2(this.#model);
      const dispatch = (handler, immediate = false) => (event2) => {
        const result = handler(event2);
        if (result instanceof Ok) {
          this.send(new Dispatch(result[0], immediate));
        }
      };
      const prev = this.shadowRoot.childNodes[this.#adoptedStyleElements.length] ?? this.shadowRoot.appendChild(document.createTextNode(""));
      morph(prev, vdom, dispatch);
    }
    #flush(effects2 = []) {
      while (this.#queue.length > 0) {
        const msg = this.#queue.shift();
        const [next, effect] = update2(this.#model, msg);
        effects2 = effects2.concat(effect.all.toArray());
        this.#model = next;
      }
      while (effects2.length > 0) {
        const effect = effects2.shift();
        const dispatch = (msg) => this.send(new Dispatch(msg));
        const emit3 = (event2, data) => this.dispatchEvent(
          new CustomEvent(event2, {
            detail: data,
            bubbles: true,
            composed: true
          })
        );
        const select = () => {
        };
        const root = this.shadowRoot;
        effect({ dispatch, emit: emit3, select, root });
      }
      if (this.#queue.length > 0) {
        this.#flush(effects2);
      }
    }
    async #adoptStyleSheets() {
      const pendingParentStylesheets = [];
      for (const link of document.querySelectorAll("link[rel=stylesheet]")) {
        if (link.sheet)
          continue;
        pendingParentStylesheets.push(
          new Promise((resolve, reject) => {
            link.addEventListener("load", resolve);
            link.addEventListener("error", reject);
          })
        );
      }
      await Promise.allSettled(pendingParentStylesheets);
      while (this.#adoptedStyleElements.length) {
        this.#adoptedStyleElements.shift().remove();
        this.shadowRoot.firstChild.remove();
      }
      this.shadowRoot.adoptedStyleSheets = this.getRootNode().adoptedStyleSheets;
      const pending = [];
      for (const sheet of document.styleSheets) {
        try {
          this.shadowRoot.adoptedStyleSheets.push(sheet);
        } catch {
          try {
            const adoptedSheet = new CSSStyleSheet();
            for (const rule of sheet.cssRules) {
              adoptedSheet.insertRule(
                rule.cssText,
                adoptedSheet.cssRules.length
              );
            }
            this.shadowRoot.adoptedStyleSheets.push(adoptedSheet);
          } catch {
            const node = sheet.ownerNode.cloneNode();
            this.shadowRoot.prepend(node);
            this.#adoptedStyleElements.push(node);
            pending.push(
              new Promise((resolve, reject) => {
                node.onload = resolve;
                node.onerror = reject;
              })
            );
          }
        }
      }
      return Promise.allSettled(pending);
    }
  };
  window.customElements.define(name2, component3);
  return new Ok(void 0);
};
var LustreServerApplication = class _LustreServerApplication {
  static start({ init: init3, update: update2, view: view2, on_attribute_change }, flags) {
    const app = new _LustreServerApplication(
      init3(flags),
      update2,
      view2,
      on_attribute_change
    );
    return new Ok((action) => app.send(action));
  }
  constructor([model, effects], update2, view2, on_attribute_change) {
    this.#model = model;
    this.#update = update2;
    this.#view = view2;
    this.#html = view2(model);
    this.#onAttributeChange = on_attribute_change;
    this.#renderers = /* @__PURE__ */ new Map();
    this.#handlers = handlers(this.#html);
    this.#tick(effects.all.toArray());
  }
  send(action) {
    if (action instanceof Attrs) {
      for (const attr of action[0]) {
        const decoder = this.#onAttributeChange.get(attr[0]);
        if (!decoder)
          continue;
        const msg = decoder(attr[1]);
        if (msg instanceof Error)
          continue;
        this.#queue.push(msg);
      }
      this.#tick();
    } else if (action instanceof Batch) {
      this.#queue = this.#queue.concat(action[0].toArray());
      this.#tick(action[1].all.toArray());
    } else if (action instanceof Debug) {
    } else if (action instanceof Dispatch) {
      this.#queue.push(action[0]);
      this.#tick();
    } else if (action instanceof Emit2) {
      const event2 = new Emit(action[0], action[1]);
      for (const [_, renderer] of this.#renderers) {
        renderer(event2);
      }
    } else if (action instanceof Event2) {
      const handler = this.#handlers.get(action[0]);
      if (!handler)
        return;
      const msg = handler(action[1]);
      if (msg instanceof Error)
        return;
      this.#queue.push(msg[0]);
      this.#tick();
    } else if (action instanceof Subscribe) {
      const attrs = keys(this.#onAttributeChange);
      const patch = new Init(attrs, this.#html);
      this.#renderers = this.#renderers.set(action[0], action[1]);
      action[1](patch);
    } else if (action instanceof Unsubscribe) {
      this.#renderers = this.#renderers.delete(action[0]);
    }
  }
  #model;
  #update;
  #queue;
  #view;
  #html;
  #renderers;
  #handlers;
  #onAttributeChange;
  #tick(effects = []) {
    this.#flush(effects);
    const vdom = this.#view(this.#model);
    const diff2 = elements(this.#html, vdom);
    if (!is_empty_element_diff(diff2)) {
      const patch = new Diff(diff2);
      for (const [_, renderer] of this.#renderers) {
        renderer(patch);
      }
    }
    this.#html = vdom;
    this.#handlers = diff2.handlers;
  }
  #flush(effects = []) {
    while (this.#queue.length > 0) {
      const msg = this.#queue.shift();
      const [next, effect] = this.#update(this.#model, msg);
      effects = effects.concat(effect.all.toArray());
      this.#model = next;
    }
    while (effects.length > 0) {
      const effect = effects.shift();
      const dispatch = (msg) => this.send(new Dispatch(msg));
      const emit3 = (event2, data) => this.root.dispatchEvent(
        new CustomEvent(event2, {
          detail: data,
          bubbles: true,
          composed: true
        })
      );
      const select = () => {
      };
      const root = null;
      effect({ dispatch, emit: emit3, select, root });
    }
    if (this.#queue.length > 0) {
      this.#flush(effects);
    }
  }
};
var start_server_application = LustreServerApplication.start;
var is_browser = () => globalThis.window && window.document;

// build/dev/javascript/gtempo/gtempo/internal.mjs
var imprecise_day_microseconds = 864e8;
function imprecise_days(days2) {
  return days2 * imprecise_day_microseconds;
}
function as_days_imprecise(microseconds2) {
  return divideInt(microseconds2, imprecise_day_microseconds);
}
var hour_microseconds = 36e8;
var minute_microseconds = 6e7;
var second_microseconds = 1e6;

// build/dev/javascript/gtempo/tempo_ffi.mjs
function now() {
  return Date.now() * 1e3;
}
function local_offset() {
  return -(/* @__PURE__ */ new Date()).getTimezoneOffset();
}
function now_monotonic() {
  return Math.trunc(performance.now() * 1e3);
}
var unique = 1;
function now_unique() {
  return unique++;
}

// build/dev/javascript/gtempo/tempo.mjs
var Instant = class extends CustomType {
  constructor(timestamp_utc_us, offset_local_us, monotonic_us, unique2) {
    super();
    this.timestamp_utc_us = timestamp_utc_us;
    this.offset_local_us = offset_local_us;
    this.monotonic_us = monotonic_us;
    this.unique = unique2;
  }
};
var DateTime = class extends CustomType {
  constructor(date2, time2, offset2) {
    super();
    this.date = date2;
    this.time = time2;
    this.offset = offset2;
  }
};
var NaiveDateTime = class extends CustomType {
  constructor(date2, time2) {
    super();
    this.date = date2;
    this.time = time2;
  }
};
var Offset = class extends CustomType {
  constructor(minutes2) {
    super();
    this.minutes = minutes2;
  }
};
var Date2 = class extends CustomType {
  constructor(year, month, day) {
    super();
    this.year = year;
    this.month = month;
    this.day = day;
  }
};
var Jan = class extends CustomType {
};
var Feb = class extends CustomType {
};
var Mar = class extends CustomType {
};
var Apr = class extends CustomType {
};
var May = class extends CustomType {
};
var Jun = class extends CustomType {
};
var Jul = class extends CustomType {
};
var Aug = class extends CustomType {
};
var Sep = class extends CustomType {
};
var Oct = class extends CustomType {
};
var Nov = class extends CustomType {
};
var Dec = class extends CustomType {
};
var MonthYear = class extends CustomType {
  constructor(month, year) {
    super();
    this.month = month;
    this.year = year;
  }
};
var Time = class extends CustomType {
  constructor(hour, minute, second, microsecond) {
    super();
    this.hour = hour;
    this.minute = minute;
    this.second = second;
    this.microsecond = microsecond;
  }
};
var Duration = class extends CustomType {
  constructor(microseconds2) {
    super();
    this.microseconds = microseconds2;
  }
};
function datetime(date2, time2, offset2) {
  return new DateTime(date2, time2, offset2);
}
function datetime_drop_offset(datetime2) {
  return new NaiveDateTime(datetime2.date, datetime2.time);
}
function naive_datetime_get_date(naive_datetime2) {
  return naive_datetime2.date;
}
function naive_datetime_get_time(naive_datetime2) {
  return naive_datetime2.time;
}
function offset_to_duration(offset2) {
  let _pipe = -offset2.minutes * 6e7;
  return new Duration(_pipe);
}
function date_get_year(date2) {
  return date2.year;
}
function date_get_month(date2) {
  return date2.month;
}
function date_get_month_year(date2) {
  return new MonthYear(date2.month, date2.year);
}
function date_get_day(date2) {
  return date2.day;
}
function month_from_int(month) {
  if (month === 1) {
    return new Ok(new Jan());
  } else if (month === 2) {
    return new Ok(new Feb());
  } else if (month === 3) {
    return new Ok(new Mar());
  } else if (month === 4) {
    return new Ok(new Apr());
  } else if (month === 5) {
    return new Ok(new May());
  } else if (month === 6) {
    return new Ok(new Jun());
  } else if (month === 7) {
    return new Ok(new Jul());
  } else if (month === 8) {
    return new Ok(new Aug());
  } else if (month === 9) {
    return new Ok(new Sep());
  } else if (month === 10) {
    return new Ok(new Oct());
  } else if (month === 11) {
    return new Ok(new Nov());
  } else if (month === 12) {
    return new Ok(new Dec());
  } else {
    return new Error(void 0);
  }
}
function date_from_unix_seconds(unix_ts) {
  let z = divideInt(unix_ts, 86400) + 719468;
  let era = divideInt(
    (() => {
      let $2 = z >= 0;
      if ($2) {
        return z;
      } else {
        return z - 146096;
      }
    })(),
    146097
  );
  let doe = z - era * 146097;
  let yoe = divideInt(
    doe - divideInt(doe, 1460) + divideInt(doe, 36524) - divideInt(
      doe,
      146096
    ),
    365
  );
  let y = yoe + era * 400;
  let doy = doe - (365 * yoe + divideInt(yoe, 4) - divideInt(yoe, 100));
  let mp = divideInt(5 * doy + 2, 153);
  let d = doy - divideInt(153 * mp + 2, 5) + 1;
  let m = mp + (() => {
    let $2 = mp < 10;
    if ($2) {
      return 3;
    } else {
      return -9;
    }
  })();
  let y$1 = (() => {
    let $2 = m <= 2;
    if ($2) {
      return y + 1;
    } else {
      return y;
    }
  })();
  let $ = month_from_int(m);
  if (!$.isOk()) {
    throw makeError(
      "let_assert",
      "tempo",
      1734,
      "date_from_unix_seconds",
      "Pattern match failed, no pattern matched the value.",
      { value: $ }
    );
  }
  let month = $[0];
  return new Date2(y$1, month, d);
}
function instant_as_utc_date(instant) {
  return date_from_unix_seconds(divideInt(instant.timestamp_utc_us, 1e6));
}
function date_from_unix_micro(unix_ts) {
  return date_from_unix_seconds(divideInt(unix_ts, 1e6));
}
function month_year_prior(month_year) {
  let $ = month_year.month;
  if ($ instanceof Jan) {
    return new MonthYear(new Dec(), month_year.year - 1);
  } else if ($ instanceof Feb) {
    return new MonthYear(new Jan(), month_year.year);
  } else if ($ instanceof Mar) {
    return new MonthYear(new Feb(), month_year.year);
  } else if ($ instanceof Apr) {
    return new MonthYear(new Mar(), month_year.year);
  } else if ($ instanceof May) {
    return new MonthYear(new Apr(), month_year.year);
  } else if ($ instanceof Jun) {
    return new MonthYear(new May(), month_year.year);
  } else if ($ instanceof Jul) {
    return new MonthYear(new Jun(), month_year.year);
  } else if ($ instanceof Aug) {
    return new MonthYear(new Jul(), month_year.year);
  } else if ($ instanceof Sep) {
    return new MonthYear(new Aug(), month_year.year);
  } else if ($ instanceof Oct) {
    return new MonthYear(new Sep(), month_year.year);
  } else if ($ instanceof Nov) {
    return new MonthYear(new Oct(), month_year.year);
  } else {
    return new MonthYear(new Nov(), month_year.year);
  }
}
function month_year_next(month_year) {
  let $ = month_year.month;
  if ($ instanceof Jan) {
    return new MonthYear(new Feb(), month_year.year);
  } else if ($ instanceof Feb) {
    return new MonthYear(new Mar(), month_year.year);
  } else if ($ instanceof Mar) {
    return new MonthYear(new Apr(), month_year.year);
  } else if ($ instanceof Apr) {
    return new MonthYear(new May(), month_year.year);
  } else if ($ instanceof May) {
    return new MonthYear(new Jun(), month_year.year);
  } else if ($ instanceof Jun) {
    return new MonthYear(new Jul(), month_year.year);
  } else if ($ instanceof Jul) {
    return new MonthYear(new Aug(), month_year.year);
  } else if ($ instanceof Aug) {
    return new MonthYear(new Sep(), month_year.year);
  } else if ($ instanceof Sep) {
    return new MonthYear(new Oct(), month_year.year);
  } else if ($ instanceof Oct) {
    return new MonthYear(new Nov(), month_year.year);
  } else if ($ instanceof Nov) {
    return new MonthYear(new Dec(), month_year.year);
  } else {
    return new MonthYear(new Jan(), month_year.year + 1);
  }
}
function is_leap_year(year) {
  let $ = remainderInt(year, 4) === 0;
  if ($) {
    let $1 = remainderInt(year, 100) === 0;
    if ($1) {
      let $2 = remainderInt(year, 400) === 0;
      if ($2) {
        return true;
      } else {
        return false;
      }
    } else {
      return true;
    }
  } else {
    return false;
  }
}
function date_to_unix_seconds(date2) {
  let full_years_since_epoch = date_get_year(date2) - 1970;
  let full_elapsed_leap_years_since_epoch = divideInt(
    full_years_since_epoch + 1,
    4
  );
  let full_elapsed_non_leap_years_since_epoch = full_years_since_epoch - full_elapsed_leap_years_since_epoch;
  let year_sec = full_elapsed_non_leap_years_since_epoch * 31536e3 + full_elapsed_leap_years_since_epoch * 31622400;
  let feb_milli = (() => {
    let $ = is_leap_year(
      (() => {
        let _pipe = date2;
        return date_get_year(_pipe);
      })()
    );
    if ($) {
      return 2505600;
    } else {
      return 2419200;
    }
  })();
  let month_sec = (() => {
    let $ = (() => {
      let _pipe = date2;
      return date_get_month(_pipe);
    })();
    if ($ instanceof Jan) {
      return 0;
    } else if ($ instanceof Feb) {
      return 2678400;
    } else if ($ instanceof Mar) {
      return 2678400 + feb_milli;
    } else if ($ instanceof Apr) {
      return 5356800 + feb_milli;
    } else if ($ instanceof May) {
      return 7948800 + feb_milli;
    } else if ($ instanceof Jun) {
      return 10627200 + feb_milli;
    } else if ($ instanceof Jul) {
      return 13219200 + feb_milli;
    } else if ($ instanceof Aug) {
      return 15897600 + feb_milli;
    } else if ($ instanceof Sep) {
      return 18576e3 + feb_milli;
    } else if ($ instanceof Oct) {
      return 21168e3 + feb_milli;
    } else if ($ instanceof Nov) {
      return 23846400 + feb_milli;
    } else {
      return 26438400 + feb_milli;
    }
  })();
  let day_sec = (date_get_day(date2) - 1) * 86400;
  return year_sec + month_sec + day_sec;
}
function date_to_unix_micro(date2) {
  return date_to_unix_seconds(date2) * 1e6;
}
function month_year_days_of(my) {
  let $ = my.month;
  if ($ instanceof Jan) {
    return 31;
  } else if ($ instanceof Mar) {
    return 31;
  } else if ($ instanceof May) {
    return 31;
  } else if ($ instanceof Jul) {
    return 31;
  } else if ($ instanceof Aug) {
    return 31;
  } else if ($ instanceof Oct) {
    return 31;
  } else if ($ instanceof Dec) {
    return 31;
  } else {
    let $1 = my.month;
    if ($1 instanceof Apr) {
      return 30;
    } else if ($1 instanceof Jun) {
      return 30;
    } else if ($1 instanceof Sep) {
      return 30;
    } else if ($1 instanceof Nov) {
      return 30;
    } else {
      let $2 = is_leap_year(my.year);
      if ($2) {
        return 29;
      } else {
        return 28;
      }
    }
  }
}
function date_subtract(loop$date, loop$days) {
  while (true) {
    let date2 = loop$date;
    let days2 = loop$days;
    let $ = days2 < date2.day;
    if ($) {
      return new Date2(date2.year, date2.month, date2.day - days2);
    } else {
      let prior_month = month_year_prior(
        (() => {
          let _pipe = date2;
          return date_get_month_year(_pipe);
        })()
      );
      loop$date = new Date2(
        prior_month.year,
        prior_month.month,
        month_year_days_of(prior_month)
      );
      loop$days = days2 - date_get_day(date2);
    }
  }
}
function month_days_of(month, year) {
  return month_year_days_of(new MonthYear(month, year));
}
function date_add(loop$date, loop$days) {
  while (true) {
    let date2 = loop$date;
    let days2 = loop$days;
    let days_left_this_month = month_days_of(date2.month, date2.year) - date2.day;
    let $ = days2 <= days_left_this_month;
    if ($) {
      return new Date2(date2.year, date2.month, date2.day + days2);
    } else {
      let next_month = month_year_next(
        (() => {
          let _pipe = date2;
          return date_get_month_year(_pipe);
        })()
      );
      loop$date = new Date2(next_month.year, next_month.month, 1);
      loop$days = days2 - days_left_this_month - 1;
    }
  }
}
function time_to_microseconds(time2) {
  return time2.hour * hour_microseconds + time2.minute * minute_microseconds + time2.second * second_microseconds + time2.microsecond;
}
function time_from_microseconds(microseconds2) {
  let in_range_micro = remainderInt(
    microseconds2,
    imprecise_day_microseconds
  );
  let adj_micro = (() => {
    let $ = in_range_micro < 0;
    if ($) {
      return in_range_micro + imprecise_day_microseconds;
    } else {
      return in_range_micro;
    }
  })();
  let hour = divideInt(adj_micro, 36e8);
  let minute = divideInt(adj_micro - hour * 36e8, 6e7);
  let second = divideInt(
    adj_micro - hour * 36e8 - minute * 6e7,
    1e6
  );
  let microsecond = adj_micro - hour * 36e8 - minute * 6e7 - second * 1e6;
  return new Time(hour, minute, second, microsecond);
}
function time_from_unix_micro(unix_ts) {
  let _pipe = unix_ts - date_to_unix_micro(date_from_unix_micro(unix_ts));
  return time_from_microseconds(_pipe);
}
function instant_as_utc_time(instant) {
  return time_from_unix_micro(instant.timestamp_utc_us);
}
function time_to_duration(time2) {
  let _pipe = time_to_microseconds(time2);
  return new Duration(_pipe);
}
function time_add(a, b) {
  let _pipe = time_to_microseconds(a) + b.microseconds;
  return time_from_microseconds(_pipe);
}
function time_subtract(a, b) {
  let _pipe = time_to_microseconds(a) - b.microseconds;
  return time_from_microseconds(_pipe);
}
function duration(microseconds2) {
  return new Duration(microseconds2);
}
function duration_days(days2) {
  let _pipe = days2;
  let _pipe$1 = imprecise_days(_pipe);
  return duration(_pipe$1);
}
function duration_increase(a, b) {
  return new Duration(a.microseconds + b.microseconds);
}
function duration_decrease(a, b) {
  return new Duration(a.microseconds - b.microseconds);
}
function duration_absolute(duration2) {
  let $ = duration2.microseconds < 0;
  if ($) {
    let _pipe = -duration2.microseconds;
    return new Duration(_pipe);
  } else {
    return duration2;
  }
}
function duration_as_days(duration2) {
  let _pipe = duration2.microseconds;
  return as_days_imprecise(_pipe);
}
function duration_as_microseconds(duration2) {
  return duration2.microseconds;
}
function offset_local_micro() {
  return local_offset() * 6e7;
}
function now2() {
  return new Instant(
    now(),
    offset_local_micro(),
    now_monotonic(),
    now_unique()
  );
}
var utc = /* @__PURE__ */ new Offset(0);
function instant_as_utc_datetime(instant) {
  return new DateTime(
    instant_as_utc_date(instant),
    instant_as_utc_time(instant),
    utc
  );
}
function naive_datetime_subtract(datetime2, duration_to_subtract) {
  return lazy_guard(
    duration_to_subtract.microseconds < 0,
    () => {
      let _pipe = datetime2;
      return naive_datetime_add(_pipe, duration_absolute(duration_to_subtract));
    },
    () => {
      let days_to_sub = duration_as_days(duration_to_subtract);
      let time_to_sub = duration_decrease(
        duration_to_subtract,
        duration_days(days_to_sub)
      );
      let new_time_as_micro = (() => {
        let _pipe = datetime2.time;
        let _pipe$1 = time_to_duration(_pipe);
        let _pipe$2 = duration_decrease(_pipe$1, time_to_sub);
        return duration_as_microseconds(_pipe$2);
      })();
      let $ = (() => {
        let $1 = new_time_as_micro < 0;
        if ($1) {
          return [
            new_time_as_micro + imprecise_day_microseconds,
            days_to_sub + 1
          ];
        } else {
          return [new_time_as_micro, days_to_sub];
        }
      })();
      let new_time_as_micro$1 = $[0];
      let days_to_sub$1 = $[1];
      let time_to_sub$1 = new Duration(
        time_to_microseconds(datetime2.time) - new_time_as_micro$1
      );
      let new_date$1 = (() => {
        let _pipe = datetime2.date;
        return date_subtract(_pipe, days_to_sub$1);
      })();
      let new_time$1 = (() => {
        let _pipe = datetime2.time;
        return time_subtract(_pipe, time_to_sub$1);
      })();
      return new NaiveDateTime(new_date$1, new_time$1);
    }
  );
}
function naive_datetime_add(datetime2, duration_to_add) {
  return lazy_guard(
    duration_to_add.microseconds < 0,
    () => {
      let _pipe = datetime2;
      return naive_datetime_subtract(_pipe, duration_absolute(duration_to_add));
    },
    () => {
      let days_to_add = duration_as_days(duration_to_add);
      let time_to_add = duration_decrease(
        duration_to_add,
        duration_days(days_to_add)
      );
      let new_time_as_micro = (() => {
        let _pipe = datetime2.time;
        let _pipe$1 = time_to_duration(_pipe);
        let _pipe$2 = duration_increase(_pipe$1, time_to_add);
        return duration_as_microseconds(_pipe$2);
      })();
      let $ = (() => {
        let $1 = new_time_as_micro >= imprecise_day_microseconds;
        if ($1) {
          return [
            new_time_as_micro - imprecise_day_microseconds,
            days_to_add + 1
          ];
        } else {
          return [new_time_as_micro, days_to_add];
        }
      })();
      let new_time_as_micro$1 = $[0];
      let days_to_add$1 = $[1];
      let time_to_add$1 = new Duration(
        new_time_as_micro$1 - time_to_microseconds(datetime2.time)
      );
      let new_date$1 = (() => {
        let _pipe = datetime2.date;
        return date_add(_pipe, days_to_add$1);
      })();
      let new_time$1 = (() => {
        let _pipe = datetime2.time;
        return time_add(_pipe, time_to_add$1);
      })();
      return new NaiveDateTime(new_date$1, new_time$1);
    }
  );
}
function datetime_apply_offset(datetime2) {
  let applied = (() => {
    let _pipe = datetime2;
    let _pipe$1 = datetime_drop_offset(_pipe);
    return naive_datetime_add(_pipe$1, offset_to_duration(datetime2.offset));
  })();
  return new NaiveDateTime(applied.date, applied.time);
}

// build/dev/javascript/gtempo/tempo/date.mjs
function from_unix_seconds(unix_ts) {
  return date_from_unix_seconds(unix_ts);
}
function to_unix_seconds(date2) {
  return date_to_unix_seconds(date2);
}
function from_unix_milli(unix_ts) {
  return from_unix_seconds(divideInt(unix_ts, 1e3));
}
function to_unix_milli(date2) {
  return to_unix_seconds(date2) * 1e3;
}
function to_unix_micro(date2) {
  return date_to_unix_micro(date2);
}

// build/dev/javascript/gtempo/tempo/time.mjs
function from_unix_milli2(unix_ts) {
  let _pipe = (unix_ts - to_unix_milli(from_unix_milli(unix_ts))) * 1e3;
  return time_from_microseconds(_pipe);
}

// build/dev/javascript/gtempo/tempo/datetime.mjs
function new$3(date2, time2, offset2) {
  return datetime(date2, time2, offset2);
}
function from_unix_milli3(unix_ts) {
  return new$3(
    from_unix_milli(unix_ts),
    from_unix_milli2(unix_ts),
    utc
  );
}
function apply_offset(datetime2) {
  return datetime_apply_offset(datetime2);
}
function to_unix_milli2(datetime2) {
  let utc_dt = (() => {
    let _pipe = datetime2;
    return apply_offset(_pipe);
  })();
  return to_unix_milli(
    (() => {
      let _pipe = utc_dt;
      return naive_datetime_get_date(_pipe);
    })()
  ) + divideInt(
    time_to_microseconds(
      (() => {
        let _pipe = utc_dt;
        return naive_datetime_get_time(_pipe);
      })()
    ),
    1e3
  );
}
function to_unix_micro2(datetime2) {
  let utc_dt = (() => {
    let _pipe = datetime2;
    return apply_offset(_pipe);
  })();
  return to_unix_micro(
    (() => {
      let _pipe = utc_dt;
      return naive_datetime_get_date(_pipe);
    })()
  ) + time_to_microseconds(
    (() => {
      let _pipe = utc_dt;
      return naive_datetime_get_time(_pipe);
    })()
  );
}

// build/dev/javascript/gtempo/tempo/instant.mjs
function now3() {
  return now2();
}
function as_utc_datetime(instant) {
  return instant_as_utc_datetime(instant);
}

// build/dev/javascript/lustre/lustre/element/html.mjs
function text2(content) {
  return text(content);
}
function style2(attrs, css) {
  return element("style", attrs, toList([text2(css)]));
}
function div(attrs, children2) {
  return element("div", attrs, children2);
}
function hr(attrs) {
  return element("hr", attrs, toList([]));
}
function p(attrs, children2) {
  return element("p", attrs, children2);
}
function br(attrs) {
  return element("br", attrs, toList([]));
}
function span(attrs, children2) {
  return element("span", attrs, children2);
}
function button(attrs, children2) {
  return element("button", attrs, children2);
}
function input(attrs) {
  return element("input", attrs, toList([]));
}

// build/dev/javascript/lustre/lustre/event.mjs
function emit2(event2, data) {
  return event(event2, data);
}
function on2(name2, handler) {
  return on(name2, handler);
}
function on_click(msg) {
  return on2("click", (_) => {
    return new Ok(msg);
  });
}
function value2(event2) {
  let _pipe = event2;
  return field("target", field("value", string))(
    _pipe
  );
}
function on_input(msg) {
  return on2(
    "input",
    (event2) => {
      let _pipe = value2(event2);
      return map3(_pipe, msg);
    }
  );
}

// build/dev/javascript/o11a_common/o11a/note.mjs
var Note = class extends CustomType {
  constructor(note_id, parent_id, significance, user_id, message, expanded_message, time2, edited) {
    super();
    this.note_id = note_id;
    this.parent_id = parent_id;
    this.significance = significance;
    this.user_id = user_id;
    this.message = message;
    this.expanded_message = expanded_message;
    this.time = time2;
    this.edited = edited;
  }
};
var Regular = class extends CustomType {
};
var Question = class extends CustomType {
};
var Answer = class extends CustomType {
};
var ToDo = class extends CustomType {
};
var ToDoDone = class extends CustomType {
};
var FindingLead = class extends CustomType {
};
var FindingComfirmation = class extends CustomType {
};
var FindingRejection = class extends CustomType {
};
var DevelperQuestion = class extends CustomType {
};
function note_significance_to_int(note_significance) {
  if (note_significance instanceof Regular) {
    return 1;
  } else if (note_significance instanceof Question) {
    return 2;
  } else if (note_significance instanceof Answer) {
    return 3;
  } else if (note_significance instanceof ToDo) {
    return 4;
  } else if (note_significance instanceof ToDoDone) {
    return 5;
  } else if (note_significance instanceof FindingLead) {
    return 6;
  } else if (note_significance instanceof FindingComfirmation) {
    return 7;
  } else if (note_significance instanceof FindingRejection) {
    return 8;
  } else {
    return 9;
  }
}
function note_significance_from_int(note_significance) {
  if (note_significance === 1) {
    return new Regular();
  } else if (note_significance === 2) {
    return new Question();
  } else if (note_significance === 3) {
    return new Answer();
  } else if (note_significance === 4) {
    return new ToDo();
  } else if (note_significance === 5) {
    return new ToDoDone();
  } else if (note_significance === 6) {
    return new FindingLead();
  } else if (note_significance === 7) {
    return new FindingComfirmation();
  } else if (note_significance === 8) {
    return new FindingRejection();
  } else if (note_significance === 9) {
    return new DevelperQuestion();
  } else {
    throw makeError(
      "panic",
      "o11a/note",
      67,
      "note_significance_from_int",
      "Invalid note significance found",
      {}
    );
  }
}
function encode_note(note) {
  return object2(
    toList([
      ["note_id", string4(note.note_id)],
      ["parent_id", string4(note.parent_id)],
      [
        "significance",
        int3(
          (() => {
            let _pipe = note.significance;
            return note_significance_to_int(_pipe);
          })()
        )
      ],
      ["user_id", int3(note.user_id)],
      ["message", string4(note.message)],
      ["expanded_message", nullable(note.expanded_message, string4)],
      [
        "time",
        int3(
          (() => {
            let _pipe = note.time;
            return to_unix_milli2(_pipe);
          })()
        )
      ],
      ["edited", bool2(note.edited)]
    ])
  );
}
function note_decoder() {
  return field2(
    "note_id",
    string3,
    (note_id) => {
      return field2(
        "parent_id",
        string3,
        (parent_id) => {
          return field2(
            "significance",
            int2,
            (significance) => {
              return field2(
                "user_id",
                int2,
                (user_id) => {
                  return field2(
                    "message",
                    string3,
                    (message) => {
                      return field2(
                        "expanded_message",
                        optional(string3),
                        (expanded_message) => {
                          return field2(
                            "time",
                            int2,
                            (time2) => {
                              return field2(
                                "edited",
                                bool,
                                (edited) => {
                                  let _pipe = new Note(
                                    note_id,
                                    parent_id,
                                    note_significance_from_int(significance),
                                    user_id,
                                    message,
                                    expanded_message,
                                    from_unix_milli3(time2),
                                    edited
                                  );
                                  return success(_pipe);
                                }
                              );
                            }
                          );
                        }
                      );
                    }
                  );
                }
              );
            }
          );
        }
      );
    }
  );
}
function structured_note_decoder() {
  return field2(
    "note_id",
    string3,
    (note_id) => {
      return field2(
        "thread_notes",
        list2(note_decoder()),
        (thread_notes) => {
          let _pipe = [note_id, thread_notes];
          return success(_pipe);
        }
      );
    }
  );
}
function decode_structured_notes(notes) {
  return try$(
    run(notes, string3),
    (notes2) => {
      let _pipe = parse(notes2, list2(structured_note_decoder()));
      return replace_error(
        _pipe,
        toList([
          new DecodeError2(
            "json-encoded note",
            inspect2(notes2),
            toList([])
          )
        ])
      );
    }
  );
}

// build/dev/javascript/o11a_common/o11a/user_interface/line_notes.mjs
var Model2 = class extends CustomType {
  constructor(user_id, line_id, notes, current_note_draft, active_thread) {
    super();
    this.user_id = user_id;
    this.line_id = line_id;
    this.notes = notes;
    this.current_note_draft = current_note_draft;
    this.active_thread = active_thread;
  }
};
var ActiveThread = class extends CustomType {
  constructor(current_thread_id, parent_note, prior_thread_id, prior_thread) {
    super();
    this.current_thread_id = current_thread_id;
    this.parent_note = parent_note;
    this.prior_thread_id = prior_thread_id;
    this.prior_thread = prior_thread;
  }
};
var ServerSetLineId = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var ServerUpdatedNotes = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UserWroteNote = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UserSubmittedNote = class extends CustomType {
  constructor(parent_id) {
    super();
    this.parent_id = parent_id;
  }
};
var UserSwitchedToThread = class extends CustomType {
  constructor(new_thread_id, parent_note) {
    super();
    this.new_thread_id = new_thread_id;
    this.parent_note = parent_note;
  }
};
var UserClosedThread = class extends CustomType {
};
function init2(_) {
  return [
    new Model2(0, "", new_map(), "", new None()),
    none()
  ];
}
function get_current_thread_id(model) {
  let $ = model.active_thread;
  if ($ instanceof Some) {
    let thread = $[0];
    return thread.current_thread_id;
  } else {
    return model.line_id;
  }
}
function on_ctrl_enter(msg) {
  return on2(
    "keydown",
    (event2) => {
      let decoder = field2(
        "ctrlKey",
        bool,
        (ctrl_key) => {
          return field2(
            "key",
            string3,
            (key) => {
              return success([ctrl_key, key]);
            }
          );
        }
      );
      let empty_error = toList([new DecodeError("", "", toList([]))]);
      return try$(
        (() => {
          let _pipe = run(event2, decoder);
          return replace_error(_pipe, empty_error);
        })(),
        (_use0) => {
          let ctrl_key = _use0[0];
          let key = _use0[1];
          if (ctrl_key && key === "Enter") {
            return new Ok(msg);
          } else {
            return new Error(empty_error);
          }
        }
      );
    }
  );
}
function view(model) {
  let current_thread_id = get_current_thread_id(model);
  let current_notes = (() => {
    let _pipe = map_get(model.notes, current_thread_id);
    return unwrap(_pipe, toList([]));
  })();
  let inline_comment_preview_text = "what is going on";
  return div(
    toList([class$("line-notes-component-container")]),
    toList([
      style2(
        toList([]),
        "\n:host {\n  display: inline-block;\n}\n\n.loc:hover {\n  color: red;\n}\n\n.line-notes-list {\n  position: absolute;\n  z-index: 99;\n  bottom: 1.4rem;\n  left: 0rem;\n  width: 30rem;\n  text-wrap: wrap;\n  background-color: white;\n  border-radius: 6px;\n  border: 1px solid black;\n  visibility: hidden;\n  opacity: 0;\n}\n\n.loc:hover + .line-notes-list,\n.line-notes-list:hover,\n.line-notes-list:focus-within {\n  visibility: visible;\n  opacity: 1;\n}\n      "
      ),
      span(
        toList([class$("loc faded-code-extras comment-preview")]),
        toList([text2(inline_comment_preview_text)])
      ),
      div(
        toList([class$("line-notes-list")]),
        toList([
          (() => {
            let $ = model.active_thread;
            if ($ instanceof Some) {
              let active_thread = $[0];
              return fragment(
                toList([
                  button(
                    toList([on_click(new UserClosedThread())]),
                    toList([text2("Close Thread")])
                  ),
                  br(toList([])),
                  text2("Current Thread: "),
                  text2(active_thread.parent_note.message),
                  hr(toList([]))
                ])
              );
            } else {
              return fragment(toList([]));
            }
          })(),
          fragment(
            map2(
              current_notes,
              (note) => {
                return fragment(
                  toList([
                    p(
                      toList([class$("line-notes-list-item")]),
                      toList([text2(note.message)])
                    ),
                    button(
                      toList([
                        on_click(
                          new UserSwitchedToThread(note.note_id, note)
                        )
                      ]),
                      toList([text2("Switch to Thread")])
                    ),
                    hr(toList([]))
                  ])
                );
              }
            )
          ),
          span(toList([]), toList([text2("Add a new comment: ")])),
          input(
            toList([
              on_input((var0) => {
                return new UserWroteNote(var0);
              }),
              on_ctrl_enter(new UserSubmittedNote(current_thread_id)),
              value(model.current_note_draft)
            ])
          )
        ])
      )
    ])
  );
}
var component_name = "line-notes";
var user_submitted_note_event = "user-submitted-line-note";
function update(model, msg) {
  if (msg instanceof ServerSetLineId) {
    let line_id = msg[0];
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_id,
          line_id,
          _record.notes,
          _record.current_note_draft,
          _record.active_thread
        );
      })(),
      none()
    ];
  } else if (msg instanceof ServerUpdatedNotes) {
    let notes = msg[0];
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_id,
          _record.line_id,
          from_list(notes),
          _record.current_note_draft,
          _record.active_thread
        );
      })(),
      none()
    ];
  } else if (msg instanceof UserWroteNote) {
    let draft = msg[0];
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_id,
          _record.line_id,
          _record.notes,
          draft,
          _record.active_thread
        );
      })(),
      none()
    ];
  } else if (msg instanceof UserSubmittedNote) {
    let parent_id = msg.parent_id;
    let now4 = (() => {
      let _pipe = now3();
      return as_utc_datetime(_pipe);
    })();
    let note_id = to_string(model.user_id) + "-" + (() => {
      let _pipe = now4;
      let _pipe$1 = to_unix_micro2(_pipe);
      return to_string(_pipe$1);
    })();
    let note = new Note(
      note_id,
      parent_id,
      new Regular(),
      model.user_id,
      model.current_note_draft,
      new None(),
      now4,
      false
    );
    let note$1 = (() => {
      let $ = model.active_thread;
      let $1 = model.current_note_draft;
      if ($ instanceof None && $1.startsWith("todo ")) {
        let rest = $1.slice(5);
        let _record = note;
        return new Note(
          _record.note_id,
          _record.parent_id,
          new ToDo(),
          _record.user_id,
          rest,
          _record.expanded_message,
          _record.time,
          _record.edited
        );
      } else if ($ instanceof None && $1.startsWith("done ")) {
        let rest = $1.slice(5);
        let _record = note;
        return new Note(
          _record.note_id,
          _record.parent_id,
          new ToDoDone(),
          _record.user_id,
          rest,
          _record.expanded_message,
          _record.time,
          _record.edited
        );
      } else if ($ instanceof None && $1.startsWith("? ")) {
        let rest = $1.slice(2);
        let _record = note;
        return new Note(
          _record.note_id,
          _record.parent_id,
          new Question(),
          _record.user_id,
          rest,
          _record.expanded_message,
          _record.time,
          _record.edited
        );
      } else if ($ instanceof None && $1.startsWith(", ")) {
        let rest = $1.slice(2);
        let _record = note;
        return new Note(
          _record.note_id,
          _record.parent_id,
          new Answer(),
          _record.user_id,
          rest,
          _record.expanded_message,
          _record.time,
          _record.edited
        );
      } else if ($ instanceof None && $1.startsWith("! ")) {
        let rest = $1.slice(2);
        let _record = note;
        return new Note(
          _record.note_id,
          _record.parent_id,
          new FindingLead(),
          _record.user_id,
          rest,
          _record.expanded_message,
          _record.time,
          _record.edited
        );
      } else if ($ instanceof None && $1.startsWith(". ")) {
        let rest = $1.slice(2);
        let _record = note;
        return new Note(
          _record.note_id,
          _record.parent_id,
          new FindingRejection(),
          _record.user_id,
          rest,
          _record.expanded_message,
          _record.time,
          _record.edited
        );
      } else if ($ instanceof None && $1.startsWith("!! ")) {
        let rest = $1.slice(3);
        let _record = note;
        return new Note(
          _record.note_id,
          _record.parent_id,
          new FindingComfirmation(),
          _record.user_id,
          rest,
          _record.expanded_message,
          _record.time,
          _record.edited
        );
      } else {
        return note;
      }
    })();
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_id,
          _record.line_id,
          _record.notes,
          "",
          _record.active_thread
        );
      })(),
      emit2(user_submitted_note_event, encode_note(note$1))
    ];
  } else if (msg instanceof UserSwitchedToThread) {
    let new_thread_id = msg.new_thread_id;
    let parent_note = msg.parent_note;
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_id,
          _record.line_id,
          _record.notes,
          _record.current_note_draft,
          new Some(
            new ActiveThread(
              new_thread_id,
              parent_note,
              get_current_thread_id(model),
              model.active_thread
            )
          )
        );
      })(),
      none()
    ];
  } else {
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_id,
          _record.line_id,
          _record.notes,
          _record.current_note_draft,
          (() => {
            let _pipe = model.active_thread;
            let _pipe$1 = map(
              _pipe,
              (thread) => {
                return thread.prior_thread;
              }
            );
            return flatten(_pipe$1);
          })()
        );
      })(),
      none()
    ];
  }
}
function component2() {
  return component(
    init2,
    update,
    view,
    from_list(
      toList([
        [
          "line-notes",
          (dy) => {
            let $ = decode_structured_notes(dy);
            if ($.isOk()) {
              let notes = $[0];
              return new Ok(new ServerUpdatedNotes(notes));
            } else {
              return new Error(
                toList([
                  new DecodeError(
                    "line-notes",
                    inspect2(dy),
                    toList([])
                  )
                ])
              );
            }
          }
        ],
        [
          "line-id",
          (dy) => {
            let $ = run(dy, string3);
            if ($.isOk()) {
              let line_id = $[0];
              return new Ok(new ServerSetLineId(line_id));
            } else {
              return new Error(
                toList([
                  new DecodeError(
                    "line-id",
                    inspect2(dy),
                    toList([])
                  )
                ])
              );
            }
          }
        ]
      ])
    )
  );
}

// build/dev/javascript/o11a_client/o11a/client/line_notes.mjs
function register() {
  return component2();
}
var name = component_name;

// build/.lustre/entry.mjs
make_lustre_client_component(register(), name);
