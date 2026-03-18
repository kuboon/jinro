"use jco";

function promiseWithResolvers() {
  if (Promise.withResolvers) {
    return Promise.withResolvers();
  } else {
    let resolve;
    let reject;
    const promise = new Promise((res, rej) => {
      resolve = res;
      reject = rej;
    });
    return { promise, resolve, reject };
  }
}

const _debugLog = (...args) => {
  if (!globalThis?.process?.env?.JCO_DEBUG) { return; }
  console.debug(...args);
};
const ASYNC_DETERMINISM = 'random';
const GLOBAL_COMPONENT_MEMORY_MAP = new Map();
const CURRENT_TASK_META = {};

function _getGlobalCurrentTaskMeta(componentIdx) {
  const v = CURRENT_TASK_META[componentIdx];
  if (v === undefined) { return v; }
  return { ...v };
}

function _setGlobalCurrentTaskMeta(args) {
  if (!args) { throw new TypeError('args missing'); }
  if (args.taskID === undefined) { throw new TypeError('missing task ID'); }
  if (args.componentIdx === undefined) { throw new TypeError('missing component idx'); }
  const { taskID, componentIdx } = args;
  return CURRENT_TASK_META[componentIdx] = { taskID, componentIdx };
}

function _withGlobalCurrentTaskMeta(args) {
  _debugLog('[_withGlobalCurrentTaskMeta()] args', args);
  if (!args) { throw new TypeError('args missing'); }
  if (args.taskID === undefined) { throw new TypeError('missing task ID'); }
  if (args.componentIdx === undefined) { throw new TypeError('missing component idx'); }
  if (!args.fn) { throw new TypeError('missing fn'); }
  const { taskID, componentIdx, fn } = args;

  try {
    CURRENT_TASK_META[componentIdx] = { taskID, componentIdx };
    return fn();
  } catch (err) {
    _debugLog("error while executing sync callee/callback", {
      ...args,
      err,
    });
    throw err;
  } finally {
    CURRENT_TASK_META[componentIdx] = null;
  }
}

async function _withGlobalCurrentTaskMetaAsync(args) {
  _debugLog('[_withGlobalCurrentTaskMetaAsync()] args', args);
  if (!args) { throw new TypeError('args missing'); }
  if (args.taskID === undefined) { throw new TypeError('missing task ID'); }
  if (args.componentIdx === undefined) { throw new TypeError('missing component idx'); }
  if (!args.fn) { throw new TypeError('missing fn'); }
  const { taskID, componentIdx, fn } = args;

  // If there is already an async task executing, we must wait for it
  // to complete before we can can run the closure we were given
  //
  let current = CURRENT_TASK_META[componentIdx];
  let cstate;
  if (current && current.taskID !== taskID) {
    cstate = getOrCreateAsyncState(componentIdx);
    while (current && current.taskID !== taskID) {
      const { promise, resolve } = Promise.withResolvers();
      cstate.onNextExclusiveRelease(resolve);
      await promise;
      current = CURRENT_TASK_META[componentIdx];
    }

    // Since we've just waited for the component to not be locked, re-lock
    // exclusivity so we can run the fn below (likely a callee/callback)
    cstate.exclusiveLock();
  }

  try {
    CURRENT_TASK_META[componentIdx] = { taskID, componentIdx };
    return await fn();
  } catch (err) {
    _debugLog("error while executing async callee/callback", {
      ...args,
      err,
    });
    throw err;
  } finally {
    CURRENT_TASK_META[componentIdx] = null;
  }
}

async function _clearCurrentTask(args) {
  _debugLog('[_clearCurrentTask()] args', args);
  if (!args) { throw new TypeError('args missing'); }
  if (args.taskID === undefined) { throw new TypeError('missing task ID'); }
  if (args.componentIdx === undefined) { throw new TypeError('missing component idx'); }
  const { taskID, componentIdx } = args;

  const meta = CURRENT_TASK_META[componentIdx];
  if (!meta) { throw new Error(`missing current task meta for component idx [${componentIdx}]`); }

  if (meta.taskID !== taskID) {
    throw new Error(`task ID [${meta.taskID}] != requested ID [${taskID}]`);
  }
  if (meta.componentIdx !== componentIdx) {
    throw new Error(`component idx [${meta.componentIdx}] != requested idx [${componentIdx}]`);
  }

  CURRENT_TASK_META[componentIdx] = null;
}

function lookupMemoriesForComponent(args) {
  const { componentIdx } = args ?? {};
  if (args.componentIdx === undefined) { throw new TypeError("missing component idx"); }

  const metas = GLOBAL_COMPONENT_MEMORY_MAP.get(componentIdx);
  if (!metas) { return []; }

  if (args.memoryIdx === undefined) {
    return Object.values(metas);
  }

  const meta = metas[args.memoryIdx];
  return meta?.memory;
}

function registerGlobalMemoryForComponent(args) {
  const { componentIdx, memory, memoryIdx } = args ?? {};
  if (componentIdx === undefined) { throw new TypeError('missing component idx'); }
  if (memory === undefined && memoryIdx === undefined) { throw new TypeError('missing both memory & memory idx'); }
  let inner = GLOBAL_COMPONENT_MEMORY_MAP.get(componentIdx);
  if (!inner) {
    inner = {};
    GLOBAL_COMPONENT_MEMORY_MAP.set(componentIdx, inner);
  }

  inner[memoryIdx] = { memory, memoryIdx, componentIdx };
}

class RepTable {
  #data = [0, null];
  #target;

  constructor(args) {
    this.target = args?.target;
  }

  data() { return this.#data; }

  insert(val) {
    _debugLog('[RepTable#insert()] args', { val, target: this.target });
    const freeIdx = this.#data[0];
    if (freeIdx === 0) {
      this.#data.push(val);
      this.#data.push(null);
      const rep = (this.#data.length >> 1) - 1;
      _debugLog('[RepTable#insert()] inserted', { val, target: this.target, rep });
      return rep;
    }
    this.#data[0] = this.#data[freeIdx << 1];
    const placementIdx = freeIdx << 1;
    this.#data[placementIdx] = val;
    this.#data[placementIdx + 1] = null;
    _debugLog('[RepTable#insert()] inserted', { val, target: this.target, rep: freeIdx });
    return freeIdx;
  }

  get(rep) {
    _debugLog('[RepTable#get()] args', { rep, target: this.target });
    if (rep === 0) { throw new Error('invalid resource rep during get, (cannot be 0)'); }

    const baseIdx = rep << 1;
    const val = this.#data[baseIdx];
    return val;
  }

  contains(rep) {
    _debugLog('[RepTable#contains()] args', { rep, target: this.target });
    if (rep === 0) { throw new Error('invalid resource rep during contains, (cannot be 0)'); }

    const baseIdx = rep << 1;
    return !!this.#data[baseIdx];
  }

  remove(rep) {
    _debugLog('[RepTable#remove()] args', { rep, target: this.target });
    if (rep === 0) { throw new Error('invalid resource rep during remove, (cannot be 0)'); }
    if (this.#data.length === 2) { throw new Error('invalid'); }

    const baseIdx = rep << 1;
    const val = this.#data[baseIdx];

    this.#data[baseIdx] = this.#data[0];
    this.#data[0] = rep;

    return val;
  }

  clear() {
    _debugLog('[RepTable#clear()] args', { rep, target: this.target });
    this.#data = [0, null];
  }
}
const _coinFlip = () => { return Math.random() > 0.5; };
let SCOPE_ID = 0;
const I32_MIN = -2_147_483_648;
const I32_MAX = 2_147_483_647;
const _typeCheckValidI32 = (n) => typeof n === 'number' && n >= I32_MIN && n <= I32_MAX;

const _typeCheckAsyncFn= (f) => {
  return f instanceof ASYNC_FN_CTOR;
};

const ASYNC_FN_CTOR = (async () => {}).constructor;

function clearCurrentTask(componentIdx, taskID) {
  _debugLog('[clearCurrentTask()] args', { componentIdx, taskID });

  if (componentIdx === undefined || componentIdx === null) {
    throw new Error('missing/invalid component instance index while ending current task');
  }

  const tasks = ASYNC_TASKS_BY_COMPONENT_IDX.get(componentIdx);
  if (!tasks || !Array.isArray(tasks)) {
    throw new Error('missing/invalid tasks for component instance while ending task');
  }
  if (tasks.length == 0) {
    throw new Error(`no current tasks for component instance [${componentIdx}] while ending task`);
  }

  if (taskID !== undefined) {
    const last = tasks[tasks.length - 1];
    if (last.id !== taskID) {
      // throw new Error('current task does not match expected task ID');
      return;
    }
  }

  ASYNC_CURRENT_TASK_IDS.pop();
  ASYNC_CURRENT_COMPONENT_IDXS.pop();

  const taskMeta = tasks.pop();
  return taskMeta.task;
}
const CURRENT_TASK_MAY_BLOCK = new WebAssembly.Global({ value: 'i32', mutable: true }, 0);
const ASYNC_CURRENT_TASK_IDS = [];
const ASYNC_CURRENT_COMPONENT_IDXS = [];

function unpackCallbackResult(result) {
  if (!(_typeCheckValidI32(result))) { throw new Error('invalid callback return value [' + result + '], not a valid i32'); }
  const eventCode = result & 0xF;
  if (eventCode < 0 || eventCode > 3) {
    throw new Error('invalid async return value [' + eventCode + '], outside callback code range');
  }
  if (result < 0 || result >= 2**32) { throw new Error('invalid callback result'); }
  // TODO: table max length check?
  const waitableSetRep = result >> 4;
  return [eventCode, waitableSetRep];
}

class AsyncSubtask {
  static _ID = 0n;

  static State = {
    STARTING: 0,
    STARTED: 1,
    RETURNED: 2,
    CANCELLED_BEFORE_STARTED: 3,
    CANCELLED_BEFORE_RETURNED: 4,
  };

  #id;
  #state = AsyncSubtask.State.STARTING;
  #componentIdx;

  #parentTask;
  #childTask = null;

  #dropped = false;
  #cancelRequested = false;

  #memoryIdx = null;
  #lenders = null;

  #waitable = null;

  #callbackFn = null;
  #callbackFnName = null;

  #postReturnFn = null;
  #onProgressFn = null;
  #pendingEventFn = null;

  #callMetadata = {};

  #resolved = false;

  #onResolveHandlers = [];
  #onStartHandlers = [];

  #result = null;
  #resultSet = false;

  fnName;
  target;
  isAsync;
  isManualAsync;

  constructor(args) {
    if (typeof args.componentIdx !== 'number') {
      throw new Error('invalid componentIdx for subtask creation');
    }
    this.#componentIdx = args.componentIdx;

    this.#id = ++AsyncSubtask._ID;
    this.fnName = args.fnName;

    if (!args.parentTask) { throw new Error('missing parent task during subtask creation'); }
    this.#parentTask = args.parentTask;

    if (args.childTask) { this.#childTask = args.childTask; }

    if (args.memoryIdx) { this.#memoryIdx = args.memoryIdx; }

    if (!args.waitable) { throw new Error("missing/invalid waitable"); }
    this.#waitable = args.waitable;

    if (args.callMetadata) { this.#callMetadata = args.callMetadata; }

    this.#lenders = [];
    this.target = args.target;
    this.isAsync = args.isAsync;
    this.isManualAsync = args.isManualAsync;
  }

  id() { return this.#id; }
  parentTaskID() { return this.#parentTask?.id(); }
  childTaskID() { return this.#childTask?.id(); }
  state() { return this.#state; }

  waitable() { return this.#waitable; }
  waitableRep() { return this.#waitable.idx(); }

  join() { return this.#waitable.join(...arguments); }
  getPendingEvent() { return this.#waitable.getPendingEvent(...arguments); }
  hasPendingEvent() { return this.#waitable.hasPendingEvent(...arguments); }
  setPendingEvent() { return this.#waitable.setPendingEvent(...arguments); }

  setTarget(tgt) { this.target = tgt; }

  getResult() {
    if (!this.#resultSet) { throw new Error("subtask result has not been set") }
    return this.#result;
  }
  setResult(v) {
    if (this.#resultSet) { throw new Error("subtask result has already been set"); }
    this.#result = v;
    this.#resultSet = true;
  }

  componentIdx() { return this.#componentIdx; }

  setChildTask(t) {
    if (!t) { throw new Error('cannot set missing/invalid child task on subtask'); }
    if (this.#childTask) { throw new Error('child task is already set on subtask'); }
    if (this.#parentTask === t) { throw new Error("parent cannot be child"); }
    this.#childTask = t;
  }
  getChildTask(t) { return this.#childTask; }

  getParentTask() { return this.#parentTask; }

  setCallbackFn(f, name) {
    if (!f) { return; }
    if (this.#callbackFn) { throw new Error('callback fn can only be set once'); }
    this.#callbackFn = f;
    this.#callbackFnName = name;
  }

  getCallbackFnName() {
    if (!this.#callbackFn) { return undefined; }
    return this.#callbackFn.name;
  }

  setPostReturnFn(f) {
    if (!f) { return; }
    if (this.#postReturnFn) { throw new Error('postReturn fn can only be set once'); }
    this.#postReturnFn = f;
  }

  setOnProgressFn(f) {
    if (this.#onProgressFn) { throw new Error('on progress fn can only be set once'); }
    this.#onProgressFn = f;
  }

  isNotStarted() {
    return this.#state == AsyncSubtask.State.STARTING;
  }

  registerOnStartHandler(f) {
    this.#onStartHandlers.push(f);
  }

  onStart(args) {
    _debugLog('[AsyncSubtask#onStart()] args', {
      componentIdx: this.#componentIdx,
      subtaskID: this.#id,
      parentTaskID: this.parentTaskID(),
      fnName: this.fnName,
    });

    if (this.#onProgressFn) { this.#onProgressFn(); }

    this.#state = AsyncSubtask.State.STARTED;

    let result;

    // If we have been provided a helper start function as a result of
    // component fusion performed by wasmtime tooling, then we can call that helper and lifts/lowers will
    // be performed for us.
    //
    // See also documentation on `HostIntrinsic::PrepareCall`
    //
    if (this.#callMetadata.startFn) {
      result = this.#callMetadata.startFn.apply(null, args?.startFnParams ?? []);
    }

    return result;
  }


  registerOnResolveHandler(f) {
    this.#onResolveHandlers.push(f);
  }

  reject(subtaskErr) {
    this.#childTask?.reject(subtaskErr);
  }

  onResolve(subtaskValue) {
    _debugLog('[AsyncSubtask#onResolve()] args', {
      componentIdx: this.#componentIdx,
      subtaskID: this.#id,
      isAsync: this.isAsync,
      childTaskID: this.childTaskID(),
      parentTaskID: this.parentTaskID(),
      parentTaskFnName: this.#parentTask?.entryFnName(),
      fnName: this.fnName,
    });

    if (this.#resolved) {
      throw new Error('subtask has already been resolved');
    }

    if (this.#onProgressFn) { this.#onProgressFn(); }

    if (subtaskValue === null) {
      if (this.#cancelRequested) {
        throw new Error('cancel was not requested, but no value present at return');
      }

      if (this.#state === AsyncSubtask.State.STARTING) {
        this.#state = AsyncSubtask.State.CANCELLED_BEFORE_STARTED;
      } else {
        if (this.#state !== AsyncSubtask.State.STARTED) {
          throw new Error('resolved subtask must have been started before cancellation');
        }
        this.#state = AsyncSubtask.State.CANCELLED_BEFORE_RETURNED;
      }
    } else {
      if (this.#state !== AsyncSubtask.State.STARTED) {
        throw new Error('resolved subtask must have been started before completion');
      }
      this.#state = AsyncSubtask.State.RETURNED;
    }

    this.setResult(subtaskValue);

    for (const f of this.#onResolveHandlers) {
      try {
        f(subtaskValue);
      } catch (err) {
        console.error("error during subtask resolve handler", err);
        throw err;
      }
    }

    const callMetadata = this.getCallMetadata();

    // TODO(fix): we should be able to easily have the caller's meomry
    // to lower into here, but it's not present in PrepareCall
    const memory = callMetadata.memory ?? this.#parentTask?.getReturnMemory() ?? lookupMemoriesForComponent({ componentIdx: this.#parentTask?.componentIdx() })[0];
    if (callMetadata && !callMetadata.returnFn && this.isAsync && callMetadata.resultPtr && memory) {
      const { resultPtr, realloc } = callMetadata;
      const lowers = callMetadata.lowers; // may have been updated in task.return of the child
      if (lowers && lowers.length > 0) {
        lowers[0]({
          componentIdx: this.#componentIdx,
          memory,
          realloc,
          vals: [subtaskValue],
          storagePtr: resultPtr,
        });
      }
    }

    this.#resolved = true;
    this.#parentTask.removeSubtask(this);
  }

  getStateNumber() { return this.#state; }
  isReturned() { return this.#state === AsyncSubtask.State.RETURNED; }

  getCallMetadata() { return this.#callMetadata; }

  isResolved() {
    if (this.#state === AsyncSubtask.State.STARTING
    || this.#state === AsyncSubtask.State.STARTED) {
      return false;
    }
    if (this.#state === AsyncSubtask.State.RETURNED
    || this.#state === AsyncSubtask.State.CANCELLED_BEFORE_STARTED
    || this.#state === AsyncSubtask.State.CANCELLED_BEFORE_RETURNED) {
      return true;
    }
    throw new Error('unrecognized internal Subtask state [' + this.#state + ']');
  }

  addLender(handle) {
    _debugLog('[AsyncSubtask#addLender()] args', { handle });
    if (!Number.isNumber(handle)) { throw new Error('missing/invalid lender handle [' + handle + ']'); }

    if (this.#lenders.length === 0 || this.isResolved()) {
      throw new Error('subtask has no lendors or has already been resolved');
    }

    handle.lends++;
    this.#lenders.push(handle);
  }

  deliverResolve() {
    _debugLog('[AsyncSubtask#deliverResolve()] args', {
      lenders: this.#lenders,
      parentTaskID: this.parentTaskID(),
      subtaskID: this.#id,
      childTaskID: this.childTaskID(),
      resolved: this.isResolved(),
      resolveDelivered: this.resolveDelivered(),
    });

    const cannotDeliverResolve = this.resolveDelivered() || !this.isResolved();
    if (cannotDeliverResolve) {
      throw new Error('subtask cannot deliver resolution twice, and the subtask must be resolved');
    }

    for (const lender of this.#lenders) {
      lender.lends--;
    }

    this.#lenders = null;
  }

  resolveDelivered() {
    _debugLog('[AsyncSubtask#resolveDelivered()] args', { });
    if (this.#lenders === null && !this.isResolved()) {
      throw new Error('invalid subtask state, lenders missing and subtask has not been resolved');
    }
    return this.#lenders === null;
  }

  drop() {
    _debugLog('[AsyncSubtask#drop()] args', {
      componentIdx: this.#componentIdx,
      parentTaskID: this.#parentTask?.id(),
      parentTaskFnName: this.#parentTask?.entryFnName(),
      childTaskID: this.#childTask?.id(),
      childTaskFnName: this.#childTask?.entryFnName(),
      subtaskFnName: this.fnName,
    });
    if (!this.#waitable) { throw new Error('missing/invalid inner waitable'); }
    if (!this.resolveDelivered()) {
      throw new Error('cannot drop subtask before resolve is delivered');
    }
    if (this.#waitable) { this.#waitable.drop() }
    this.#dropped = true;
  }

  #getComponentState() {
    const state = getOrCreateAsyncState(this.#componentIdx);
    if (!state) {
      throw new Error('invalid/missing async state for component [' + componentIdx + ']');
    }
    return state;
  }

  getWaitableHandleIdx() {
    _debugLog('[AsyncSubtask#getWaitableHandleIdx()] args', { });
    if (!this.#waitable) { throw new Error('missing/invalid waitable'); }
    return this.waitableRep();
  }
}

function _prepareCall(
memoryIdx,
getMemoryFn,
startFn,
returnFn,
callerComponentIdx,
calleeComponentIdx,
taskReturnTypeIdx,
calleeIsAsyncInt,
stringEncoding,
resultCountOrAsync,
) {
  _debugLog('[_prepareCall()]', {
    memoryIdx,
    callerComponentIdx,
    calleeComponentIdx,
    taskReturnTypeIdx,
    calleeIsAsyncInt,
    stringEncoding,
    resultCountOrAsync,
  });
  const argArray = [...arguments];

  // value passed in *may* be as large as u32::MAX which may be mangled into -2
  resultCountOrAsync >>>= 0;

  let isAsync = false;
  let hasResultPointer = false;
  if (resultCountOrAsync === 2**32 - 1) {
    // prepare async with no result (u32::MAX)
    isAsync = true;
    hasResultPointer = false;
  } else if (resultCountOrAsync === 2**32 - 2) {
    // prepare async with result (u32::MAX - 1)
    isAsync = true;
    hasResultPointer = true;
  }

  const currentCallerTaskMeta = getCurrentTask(callerComponentIdx);
  if (!currentCallerTaskMeta) {
    throw new Error('invalid/missing current task for caller during prepare call');
  }

  const currentCallerTask = currentCallerTaskMeta.task;
  if (!currentCallerTask) {
    throw new Error('unexpectedly missing task in meta for caller during prepare call');
  }

  if (currentCallerTask.componentIdx() !== callerComponentIdx) {
    throw new Error(`task component idx [${ currentCallerTask.componentIdx() }] !== [${ callerComponentIdx }] (callee ${ calleeComponentIdx })`);
  }

  let getCalleeParamsFn;
  let resultPtr = null;
  let directParamsArr;
  if (hasResultPointer) {
    directParamsArr = argArray.slice(10, argArray.length - 1);
    getCalleeParamsFn = () => directParamsArr;
    resultPtr = argArray[argArray.length - 1];
  } else {
    directParamsArr = argArray.slice(10);
    getCalleeParamsFn = () => directParamsArr;
  }

  let encoding;
  switch (stringEncoding) {
    case 0:
    encoding = 'utf8';
    break;
    case 1:
    encoding = 'utf16';
    break;
    case 2:
    encoding = 'compact-utf16';
    break;
    default:
    throw new Error(`unrecognized string encoding enum [${stringEncoding}]`);
  }

  const subtask = currentCallerTask.createSubtask({
    componentIdx: callerComponentIdx,
    parentTask: currentCallerTask,
    isAsync,
    callMetadata: {
      getMemoryFn,
      memoryIdx,
      resultPtr,
      returnFn,
      startFn,
    }
  });

  const [newTask, newTaskID] = createNewCurrentTask({
    componentIdx: calleeComponentIdx,
    isAsync,
    getCalleeParamsFn,
    entryFnName: [
    'task',
    subtask.getParentTask().id(),
    'subtask',
    subtask.id(),
    'new-prepared-async-task'
    ].join('/'),
    stringEncoding,
  });
  newTask.setParentSubtask(subtask);
  newTask.setReturnMemoryIdx(memoryIdx);
  newTask.setReturnMemory(getMemoryFn);
  subtask.setChildTask(newTask);

  newTask.subtaskMeta = {
    subtask,
    calleeComponentIdx,
    callerComponentIdx,
    getCalleeParamsFn,
    stringEncoding,
    isAsync,
  };

  _setGlobalCurrentTaskMeta({
    taskID: newTask.id(),
    componentIdx: newTask.componentIdx(),
  });
}

function _asyncStartCall(args, callee, paramCount, resultCount, flags) {
  const componentIdx = ASYNC_CURRENT_COMPONENT_IDXS.at(-1);

  const globalTaskMeta = _getGlobalCurrentTaskMeta(componentIdx);
  if (!globalTaskMeta) { throw new Error('missing global current task globalTaskMeta'); }
  const taskID = globalTaskMeta.taskID;

  _debugLog('[_asyncStartCall()] args', { args, componentIdx });
  const { getCallbackFn, callbackIdx, getPostReturnFn, postReturnIdx } = args;

  const preparedTaskMeta = getCurrentTask(componentIdx, taskID);
  if (!preparedTaskMeta) { throw new Error('unexpectedly missing current task'); }

  const preparedTask = preparedTaskMeta.task;
  if (!preparedTask) { throw new Error('unexpectedly missing current task'); }
  if (!preparedTask.subtaskMeta) { throw new Error('missing subtask meta from prepare'); }

  const {
    subtask,
    returnMemoryIdx,
    getReturnMemoryFn,
    callerComponentIdx,
    calleeComponentIdx,
    getCalleeParamsFn,
    isAsync,
    stringEncoding,
  } = preparedTask.subtaskMeta;
  if (!subtask) { throw new Error("missing subtask from cstate during async start call"); }
  if (calleeComponentIdx !== preparedTask.componentIdx()) {
    throw new Error(`meta callee idx [${calleeComponentIdx}] != current task idx [${preparedTask.componentIdx()}] during async start call`);
  }
  if (calleeComponentIdx !== componentIdx) {
    throw new Error("mismatched componentIdx for async start call (does not match prepare)");
  }

  const argArray = [...arguments];

  if (resultCount < 0 || resultCount > 1) { throw new Error('invalid/unsupported result count'); }

  const callbackFnName = 'callback_' + callbackIdx;
  const callbackFn = getCallbackFn();
  preparedTask.setCallbackFn(callbackFn, callbackFnName);
  preparedTask.setPostReturnFn(getPostReturnFn());

  if (resultCount < 0 || resultCount > 1) {
    throw new Error(`unsupported result count [${ resultCount }]`);
  }

  const params = preparedTask.getCalleeParams();
  if (paramCount !== params.length) {
    throw new Error(`unexpected callee param count [${ params.length }], _asyncStartCall invocation expected [${ paramCount }]`);
  }

  const callerComponentState = getOrCreateAsyncState(subtask.componentIdx());

  const calleeComponentState = getOrCreateAsyncState(preparedTask.componentIdx());
  const calleeBackpressure = calleeComponentState.hasBackpressure();

  // Set up a handler on subtask completion to lower results from the call into the caller's memory region.
  //
  // NOTE: during fused guest->guest calls this handler is triggered, but does not actually perform
  // lowering manually, as fused modules provider helper functions that can
  subtask.registerOnResolveHandler((res) => {
    _debugLog('[_asyncStartCall()] handling subtask result', { res, subtaskID: subtask.id() });

    let subtaskCallMeta = subtask.getCallMetadata();

    // NOTE: in the case of guest -> guest async calls, there may be no memory/realloc present,
    // as the host will intermediate the value storage/movement between calls.
    //
    // We can simply take the value and lower it as a parameter
    if (subtaskCallMeta.memory || subtaskCallMeta.realloc) {
      throw new Error("call metadata unexpectedly contains memory/realloc for guest->guest call");
    }

    const callerTask = subtask.getParentTask();
    const calleeTask = preparedTask;
    const callerMemoryIdx = callerTask.getReturnMemoryIdx();
    const callerComponentIdx = callerTask.componentIdx();

    // If a helper function was provided we are likely in a fused guest->guest call,
    // and the result will be delivered (lift/lowered) via helper function
    if (subtaskCallMeta && subtaskCallMeta.returnFn) {
      _debugLog('[_asyncStartCall()] return function present while handling subtask result, returning early (skipping lower)');

      // TODO: centralize calling of returnFn to *one place* (if possible)
      if (subtaskCallMeta.returnFnCalled) { return; }

      subtaskCallMeta.returnFn.apply(null, [subtaskCallMeta.resultPtr]);
      return;
    }

    // If there is no where to lower the results, exit early
    if (!subtaskCallMeta.resultPtr) {
      _debugLog('[_asyncStartCall()] no result ptr during subtask result handling, returning early (skipping lower)');
      return;
    }

    let callerMemory;
    if (callerMemoryIdx !== null && callerMemoryIdx !== undefined) {
      callerMemory = lookupMemoriesForComponent({ componentIdx: callerComponentIdx, memoryIdx: callerMemoryIdx });
    } else {
      const callerMemories = lookupMemoriesForComponent({ componentIdx: callerComponentIdx });
      if (callerMemories.length !== 1) { throw new Error(`unsupported amount of caller memories`); }
      callerMemory = callerMemories[0];
    }

    if (!callerMemory) {
      _debugLog('[_asyncStartCall()] missing memory', { subtaskID: subtask.id(), res });
      throw new Error(`missing memory for to guest->guest call result (subtask [${subtask.id()}])`);
    }

    const lowerFns = calleeTask.getReturnLowerFns();
    if (!lowerFns || lowerFns.length === 0) {
      _debugLog('[_asyncStartCall()] missing result lower metadata for guest->guest call', { subtaskID: subtask.id() });
      throw new Error(`missing result lower metadata for guest->guest call (subtask [${subtask.id()}])`);
    }

    if (lowerFns.length !== 1) {
      _debugLog('[_asyncStartCall()] only single result reportetd for guest->guest call', { subtaskID: subtask.id() });
      throw new Error(`only single result supported for guest->guest calls (subtask [${subtask.id()}])`);
    }

    _debugLog('[_asyncStartCall()] lowering results', { subtaskID: subtask.id() });
    lowerFns[0]({
      realloc: undefined,
      memory: callerMemory,
      vals: [res],
      storagePtr: subtaskCallMeta.resultPtr,
      componentIdx: callerComponentIdx
    });

  });

  subtask.setOnProgressFn(() => {
    subtask.setPendingEvent(() => {
      if (subtask.isResolved()) { subtask.deliverResolve(); }
      const event = {
        code: ASYNC_EVENT_CODE.SUBTASK,
        payload0: subtask.waitableRep(),
        payload1: subtask.getStateNumber(),
      };
      return event;
    });
  });

  // Start the (event) driver loop that will resolve the task
  queueMicrotask(async () => {
    let startRes = subtask.onStart({ startFnParams: params });
    startRes = Array.isArray(startRes) ? startRes : [startRes];

    await calleeComponentState.suspendTask({
      task: preparedTask,
      readyFn: () => !calleeComponentState.isExclusivelyLocked(),
    });

    const started = await preparedTask.enter();
    if (!started) {
      _debugLog('[_asyncStartCall()] task failed early', {
        taskID: preparedTask.id(),
        subtaskID: subtask.id(),
      });
      throw new Error("task failed to start");
      return;
    }

    let callbackResult;
    try {
      let jspiCallee = WebAssembly.promising(callee);
      callbackResult = await _withGlobalCurrentTaskMetaAsync({
        taskID: preparedTask.id(),
        componentIdx: preparedTask.componentIdx(),
        fn: () => {
          return jspiCallee.apply(null, startRes);
        }
      });
    } catch(err) {
      _debugLog("[_asyncStartCall()] initial subtask callee run failed", err);
      // NOTE: a good place to rejectt the parent task, if rejection API is enabled
      // subtask.reject(err);
      // subtask.getParentTask().reject(err);

      subtask.getParentTask().setErrored(err);

      return;
    }

    // If there was no callback function, we're dealing with a sync function
    // that was lifted as async without one, there is only the callee.
    if (!callbackFn) {
      _debugLog("[_asyncStartCall()] no callback, resolving w/ callee result", {
        taskID: preparedTask.id(),
        componentIdx: preparedTask.componentIdx(),
        preparedTask,
        stateNumber: preparedTask.taskState(),
        isResolved: preparedTask.isResolved(),
        callbackFn,
      });
      preparedTask.resolve([callbackResult]);
      return;
    }

    let fnName = callbackFn.fnName;
    if (!fnName) {
      fnName = [
      '<task ',
      subtask.parentTaskID(),
      '/subtask ',
      subtask.id(),
      '/task ',
      preparedTask.id(),
      '>',
      ].join("");
    }

    try {
      _debugLog("[_asyncStartCall()] starting driver loop", {
        fnName,
        componentIdx: preparedTask.componentIdx(),
        subtaskID: subtask.id(),
        childTaskID: subtask.childTaskID(),
        parentTaskID: subtask.parentTaskID(),
      });

      await _driverLoop({
        componentState: calleeComponentState,
        task: preparedTask,
        fnName,
        isAsync: true,
        callbackResult,
        resolve,
        reject
      });
    } catch (err) {
      _debugLog("[AsyncStartCall] drive loop call failure", { err });
    }

  });

  const subtaskState = subtask.getStateNumber();
  if (subtaskState < 0 || subtaskState > 2**5) {
    throw new Error('invalid subtask state, out of valid range');
  }

  _debugLog('[_asyncStartCall()] returning subtask rep & state', {
    subtask: {
      rep: subtask.waitableRep(),
      state: subtaskState,
    }
  });

  return Number(subtask.waitableRep()) << 4 | subtaskState;
}

function _syncStartCall(callbackIdx) {
  _debugLog('[_syncStartCall()] args', { callbackIdx });
  throw new Error('synchronous start call not implemented!');
}

class Waitable {
  #componentIdx;

  #pendingEventFn = null;

  #promise;
  #resolve;
  #reject;

  #waitableSet = null;

  #idx = null; // to component-global waitables

  target;

  constructor(args) {
    const { componentIdx, target } = args;
    this.#componentIdx = componentIdx;
    this.target = args.target;
    this.#resetPromise();
  }

  componentIdx() { return this.#componentIdx; }
  isInSet() { return this.#waitableSet !== null; }

  idx() { return this.#idx; }
  setIdx(idx) {
    if (idx === 0) { throw new Error("waitable idx cannot be zero"); }
    this.#idx = idx;
  }

  setTarget(tgt) { this.target = tgt; }

  #resetPromise() {
    const { promise, resolve, reject } = promiseWithResolvers()
    this.#promise = promise;
    this.#resolve = resolve;
    this.#reject = reject;
  }

  resolve() { this.#resolve(); }
  reject(err) { this.#reject(err); }
  promise() { return this.#promise; }

  hasPendingEvent() {
    // _debugLog('[Waitable#hasPendingEvent()]', {
      //     componentIdx: this.#componentIdx,
      //     waitable: this,
      //     waitableSet: this.#waitableSet,
      //     hasPendingEvent: this.#pendingEventFn !== null,
      // });
      return this.#pendingEventFn !== null;
    }

    setPendingEvent(fn) {
      _debugLog('[Waitable#setPendingEvent()] args', {
        waitable: this,
        inSet: this.#waitableSet,
      });
      this.#pendingEventFn = fn;
    }

    getPendingEvent() {
      _debugLog('[Waitable#getPendingEvent()] args', {
        waitable: this,
        inSet: this.#waitableSet,
        hasPendingEvent: this.#pendingEventFn !== null,
      });
      if (this.#pendingEventFn === null) { return null; }
      const eventFn = this.#pendingEventFn;
      this.#pendingEventFn = null;
      const e = eventFn();
      this.#resetPromise();
      return e;
    }

    join(waitableSet) {
      _debugLog('[Waitable#join()] args', {
        waitable: this,
        waitableSet: waitableSet,
      });
      if (this.#waitableSet) { this.#waitableSet.removeWaitable(this); }
      if (!waitableSet) {
        this.#waitableSet = null;
        return;
      }
      waitableSet.addWaitable(this);
      this.#waitableSet = waitableSet;
    }

    drop() {
      _debugLog('[Waitable#drop()] args', {
        componentIdx: this.#componentIdx,
        waitable: this,
      });
      if (this.hasPendingEvent()) {
        throw new Error('waitables with pending events cannot be dropped');
      }
      this.join(null);
    }

  }

  const ERR_CTX_TABLES = {};

  let dv = new DataView(new ArrayBuffer());
  const dataView = mem => dv.buffer === mem.buffer ? dv : dv = new DataView(mem.buffer);

  function toInt32(val) {
    return val >> 0;
  }
  const TEXT_DECODER_UTF8 = new TextDecoder();
  const TEXT_ENCODER_UTF8 = new TextEncoder();

  function _utf8AllocateAndEncode(s, realloc, memory) {
    if (typeof s !== 'string') {
      throw new TypeError('expected a string, received [' + typeof s + ']');
    }
    if (s.length === 0) { return { ptr: 1, len: 0 }; }
    let buf = TEXT_ENCODER_UTF8.encode(s);
    let ptr = realloc(0, 0, 1, buf.length);
    new Uint8Array(memory.buffer).set(buf, ptr);
    const res = { ptr, len: buf.length, codepoints: [...s].length };
    return res;
  }


  function createNewCurrentTask(args) {
    _debugLog('[createNewCurrentTask()] args', args);
    const {
      componentIdx,
      isAsync,
      isManualAsync,
      entryFnName,
      parentSubtaskID,
      callbackFnName,
      getCallbackFn,
      getParamsFn,
      stringEncoding,
      errHandling,
      getCalleeParamsFn,
      resultPtr,
      callingWasmExport,
    } = args;
    if (componentIdx === undefined || componentIdx === null) {
      throw new Error('missing/invalid component instance index while starting task');
    }
    let taskMetas = ASYNC_TASKS_BY_COMPONENT_IDX.get(componentIdx);
    const callbackFn = getCallbackFn ? getCallbackFn() : null;

    const newTask = new AsyncTask({
      componentIdx,
      isAsync,
      isManualAsync,
      entryFnName,
      callbackFn,
      callbackFnName,
      stringEncoding,
      getCalleeParamsFn,
      resultPtr,
      errHandling,
    });

    const newTaskID = newTask.id();
    const newTaskMeta = { id: newTaskID, componentIdx, task: newTask };

    // NOTE: do not track host tasks
    ASYNC_CURRENT_TASK_IDS.push(newTaskID);
    ASYNC_CURRENT_COMPONENT_IDXS.push(componentIdx);

    if (!taskMetas) {
      taskMetas = [newTaskMeta];
      ASYNC_TASKS_BY_COMPONENT_IDX.set(componentIdx, [newTaskMeta]);
    } else {
      taskMetas.push(newTaskMeta);
    }

    return [newTask, newTaskID];
  }
  const ASYNC_TASKS_BY_COMPONENT_IDX = new Map();

  class AsyncTask {
    static _ID = 0n;

    static State = {
      INITIAL: 'initial',
      CANCELLED: 'cancelled',
      CANCEL_PENDING: 'cancel-pending',
      CANCEL_DELIVERED: 'cancel-delivered',
      RESOLVED: 'resolved',
    }

    static BlockResult = {
      CANCELLED: 'block.cancelled',
      NOT_CANCELLED: 'block.not-cancelled',
    }

    #id;
    #componentIdx;
    #state;
    #isAsync;
    #isManualAsync;
    #entryFnName = null;

    #onResolveHandlers = [];
    #completionPromise = null;
    #rejected = false;

    #exitPromise = null;
    #onExitHandlers = [];

    #memoryIdx = null;
    #memory = null;

    #callbackFn = null;
    #callbackFnName = null;

    #postReturnFn = null;

    #getCalleeParamsFn = null;

    #stringEncoding = null;

    #parentSubtask = null;

    #needsExclusiveLock = false;

    #errHandling;

    #backpressurePromise;
    #backpressureWaiters = 0n;

    #returnLowerFns = null;

    #subtasks = [];

    #entered = false;
    #exited = false;
    #errored = null;

    cancelled = false;
    cancelRequested = false;
    alwaysTaskReturn = false;

    returnCalls =  0;
    storage = [0, 0];
    borrowedHandles = {};

    constructor(opts) {
      this.#id = ++AsyncTask._ID;

      if (opts?.componentIdx === undefined) {
        throw new TypeError('missing component id during task creation');
      }
      this.#componentIdx = opts.componentIdx;

      this.#state = AsyncTask.State.INITIAL;
      this.#isAsync = opts?.isAsync ?? false;
      this.#isManualAsync = opts?.isManualAsync ?? false;
      this.#entryFnName = opts.entryFnName;

      const {
        promise: completionPromise,
        resolve: resolveCompletionPromise,
        reject: rejectCompletionPromise,
      } = promiseWithResolvers();
      this.#completionPromise = completionPromise;

      this.#onResolveHandlers.push((results) => {
        if (this.#errored !== null) {
          rejectCompletionPromise(this.#errored);
          return;
        } else if (this.#rejected) {
          rejectCompletionPromise(results);
          return;
        }
        resolveCompletionPromise(results);
      });

      const {
        promise: exitPromise,
        resolve: resolveExitPromise,
        reject: rejectExitPromise,
      } = promiseWithResolvers();
      this.#exitPromise = exitPromise;

      this.#onExitHandlers.push(() => {
        resolveExitPromise();
      });

      if (opts.callbackFn) { this.#callbackFn = opts.callbackFn; }
      if (opts.callbackFnName) { this.#callbackFnName = opts.callbackFnName; }

      if (opts.getCalleeParamsFn) { this.#getCalleeParamsFn = opts.getCalleeParamsFn; }

      if (opts.stringEncoding) { this.#stringEncoding = opts.stringEncoding; }

      if (opts.parentSubtask) { this.#parentSubtask = opts.parentSubtask; }

      this.#needsExclusiveLock = this.isSync() || !this.hasCallback();

      if (opts.errHandling) { this.#errHandling = opts.errHandling; }
    }

    taskState() { return this.#state; }
    id() { return this.#id; }
    componentIdx() { return this.#componentIdx; }
    entryFnName() { return this.#entryFnName; }

    completionPromise() { return this.#completionPromise; }
    exitPromise() { return this.#exitPromise; }

    isAsync() { return this.#isAsync; }
    isSync() { return !this.isAsync(); }

    getErrHandling() { return this.#errHandling; }

    hasCallback() { return this.#callbackFn !== null; }

    getReturnMemoryIdx() { return this.#memoryIdx; }
    setReturnMemoryIdx(idx) {
      if (idx === null) { return; }
      this.#memoryIdx = idx;
    }

    getReturnMemory() { return this.#memory; }
    setReturnMemory(m) {
      if (m === null) { return; }
      this.#memory = m;
    }

    setReturnLowerFns(fns) { this.#returnLowerFns = fns; }
    getReturnLowerFns() { return this.#returnLowerFns; }

    setParentSubtask(subtask) {
      if (!subtask || !(subtask instanceof AsyncSubtask)) { return }
      if (this.#parentSubtask) { throw new Error('parent subtask can only be set once'); }
      this.#parentSubtask = subtask;
    }

    getParentSubtask() { return this.#parentSubtask; }

    // TODO(threads): this is very inefficient, we can pass along a root task,
    // and ideally do not need this once thread support is in place
    getRootTask() {
      let currentSubtask = this.getParentSubtask();
      let task = this;
      while (currentSubtask) {
        task = currentSubtask.getParentTask();
        currentSubtask = task.getParentSubtask();
      }
      return task;
    }

    setPostReturnFn(f) {
      if (!f) { return; }
      if (this.#postReturnFn) { throw new Error('postReturn fn can only be set once'); }
      this.#postReturnFn = f;
    }

    setCallbackFn(f, name) {
      if (!f) { return; }
      if (this.#callbackFn) { throw new Error('callback fn can only be set once'); }
      this.#callbackFn = f;
      this.#callbackFnName = name;
    }

    getCallbackFnName() {
      if (!this.#callbackFnName) { return undefined; }
      return this.#callbackFnName;
    }

    async runCallbackFn(...args) {
      if (!this.#callbackFn) { throw new Error('on callback function has been set for task'); }
      return await this.#callbackFn.apply(null, args);
    }

    getCalleeParams() {
      if (!this.#getCalleeParamsFn) { throw new Error('missing/invalid getCalleeParamsFn'); }
      return this.#getCalleeParamsFn();
    }

    mayBlock() { return this.isAsync() || this.isResolvedState() }

    mayEnter(task) {
      const cstate = getOrCreateAsyncState(this.#componentIdx);
      if (cstate.hasBackpressure()) {
        _debugLog('[AsyncTask#mayEnter()] disallowed due to backpressure', { taskID: this.#id });
        return false;
      }
      if (!cstate.callingSyncImport()) {
        _debugLog('[AsyncTask#mayEnter()] disallowed due to sync import call', { taskID: this.#id });
        return false;
      }
      const callingSyncExportWithSyncPending = cstate.callingSyncExport && !task.isAsync;
      if (!callingSyncExportWithSyncPending) {
        _debugLog('[AsyncTask#mayEnter()] disallowed due to sync export w/ sync pending', { taskID: this.#id });
        return false;
      }
      return true;
    }

    enterSync() {
      if (this.needsExclusiveLock()) {
        const cstate = getOrCreateAsyncState(this.#componentIdx);
        cstate.exclusiveLock();
      }
      return true;
    }

    async enter(opts) {
      _debugLog('[AsyncTask#enter()] args', {
        taskID: this.#id,
        componentIdx: this.#componentIdx,
        subtaskID: this.getParentSubtask()?.id(),
      });

      if (this.#entered) {
        throw new Error(`task with ID [${this.#id}] should not be entered twice`);
      }

      const cstate = getOrCreateAsyncState(this.#componentIdx);

      // If a task is either synchronous or host-provided (e.g. a host import, whether sync or async)
      // then we can avoid component-relevant tracking and immediately enter
      if (this.isSync() || opts?.isHost) {
        this.#entered = true;

        // TODO(breaking): remove once manually-spccifying async fns is removed
        // It is currently possible for an actually sync export to be specified
        // as async via JSPI
        if (this.#isManualAsync) {
          if (this.needsExclusiveLock()) { cstate.exclusiveLock(); }
        }

        return this.#entered;
      }

      if (cstate.hasBackpressure()) {
        cstate.addBackpressureWaiter();

        const result = await this.waitUntil({
          readyFn: () => !cstate.hasBackpressure(),
          cancellable: true,
        });

        cstate.removeBackpressureWaiter();

        if (result === AsyncTask.BlockResult.CANCELLED) {
          this.cancel();
          return false;
        }
      }

      if (this.needsExclusiveLock()) { cstate.exclusiveLock(); }

      this.#entered = true;
      return this.#entered;
    }

    isRunningState() { return this.#state !== AsyncTask.State.RESOLVED; }
    isResolvedState() { return this.#state === AsyncTask.State.RESOLVED; }
    isResolved() { return this.#state === AsyncTask.State.RESOLVED; }

    async waitUntil(opts) {
      const { readyFn, waitableSetRep, cancellable } = opts;
      _debugLog('[AsyncTask#waitUntil()] args', { taskID: this.#id, waitableSetRep, cancellable });

      const state = getOrCreateAsyncState(this.#componentIdx);
      const wset = state.handles.get(waitableSetRep);

      let event;

      wset.incrementNumWaiting();

      const keepGoing = await this.suspendUntil({
        readyFn: () => {
          const hasPendingEvent = wset.hasPendingEvent();
          const ready = readyFn();
          return ready && hasPendingEvent;
        },
        cancellable,
      });

      if (keepGoing) {
        event = wset.getPendingEvent();
      } else {
        event = {
          code: ASYNC_EVENT_CODE.TASK_CANCELLED,
          payload0: 0,
          payload1: 0,
        };
      }

      wset.decrementNumWaiting();

      return event;
    }

    async yieldUntil(opts) {
      const { readyFn, cancellable } = opts;
      _debugLog('[AsyncTask#yieldUntil()] args', { taskID: this.#id, cancellable });

      const keepGoing = await this.suspendUntil({ readyFn, cancellable });
      if (keepGoing) {
        return {
          code: ASYNC_EVENT_CODE.NONE,
          payload0: 0,
          payload1: 0,
        };
      }

      return {
        code: ASYNC_EVENT_CODE.TASK_CANCELLED,
        payload0: 0,
        payload1: 0,
      };
    }

    async suspendUntil(opts) {
      const { cancellable, readyFn } = opts;
      _debugLog('[AsyncTask#suspendUntil()] args', { cancellable });

      const pendingCancelled = this.deliverPendingCancel({ cancellable });
      if (pendingCancelled) { return false; }

      const completed = await this.immediateSuspendUntil({ readyFn, cancellable });
      return completed;
    }

    // TODO(threads): equivalent to thread.suspend_until()
    async immediateSuspendUntil(opts) {
      const { cancellable, readyFn } = opts;
      _debugLog('[AsyncTask#immediateSuspendUntil()] args', { cancellable, readyFn });

      const ready = readyFn();
      if (ready && ASYNC_DETERMINISM === 'random') {
        const coinFlip = _coinFlip();
        if (coinFlip) { return true }
      }

      const keepGoing = await this.immediateSuspend({ cancellable, readyFn });
      return keepGoing;
    }

    async immediateSuspend(opts) { // NOTE: equivalent to thread.suspend()
    // TODO(threads): store readyFn on the thread
    const { cancellable, readyFn } = opts;
    _debugLog('[AsyncTask#immediateSuspend()] args', { cancellable, readyFn });

    const pendingCancelled = this.deliverPendingCancel({ cancellable });
    if (pendingCancelled) { return false; }

    const cstate = getOrCreateAsyncState(this.#componentIdx);
    const keepGoing = await cstate.suspendTask({ task: this, readyFn });
    return keepGoing;
  }

  deliverPendingCancel(opts) {
    const { cancellable } = opts;
    _debugLog('[AsyncTask#deliverPendingCancel()] args', { cancellable });

    if (cancellable && this.#state === AsyncTask.State.PENDING_CANCEL) {
      this.#state = AsyncTask.State.CANCEL_DELIVERED;
      return true;
    }

    return false;
  }

  isCancelled() { return this.cancelled }

  cancel(args) {
    _debugLog('[AsyncTask#cancel()] args', { });
    if (this.taskState() !== AsyncTask.State.CANCEL_DELIVERED) {
      throw new Error(`(component [${this.#componentIdx}]) task [${this.#id}] invalid task state [${this.taskState()}] for cancellation`);
    }
    if (this.borrowedHandles.length > 0) { throw new Error('task still has borrow handles'); }
    this.cancelled = true;
    this.onResolve(args?.error ?? new Error('task cancelled'));
    this.#state = AsyncTask.State.RESOLVED;
  }

  onResolve(taskValue) {
    const handlers = this.#onResolveHandlers;
    this.#onResolveHandlers = [];
    for (const f of handlers) {
      try {
        // TODO(fix): resolve handlers getting called a ton?
        f(taskValue);
      } catch (err) {
        _debugLog("[AsyncTask#onResolve] error during task resolve handler", err);
        throw err;
      }
    }

    if (this.#parentSubtask) {
      const meta = this.#parentSubtask.getCallMetadata();
      // Run the rturn fn if it has not already been called -- this *should* have happened in
      // `task.return`, but some paths do not go through task.return (e.g. async lower of sync fn
      // which goes through prepare + async-start-call)
      if (meta.returnFn && !meta.returnFnCalled) {
        _debugLog('[AsyncTask#onResolve()] running returnFn', {
          componentIdx: this.#componentIdx,
          taskID: this.#id,
          subtaskID: this.#parentSubtask.id(),
        });
        const memory = meta.getMemoryFn();
        meta.returnFn.apply(null, [taskValue, meta.resultPtr]);
        meta.returnFnCalled = true;
      }
    }

    if (this.#postReturnFn) {
      _debugLog('[AsyncTask#onResolve()] running post return ', {
        componentIdx: this.#componentIdx,
        taskID: this.#id,
      });
      try {
        this.#postReturnFn(taskValue);
      } catch (err) {
        _debugLog("[AsyncTask#onResolve] error during task resolve handler", err);
        throw err;
      }
    }

    if (this.#parentSubtask) {
      this.#parentSubtask.onResolve(taskValue);
    }
  }

  registerOnResolveHandler(f) {
    this.#onResolveHandlers.push(f);
  }

  isRejected() { return this.#rejected; }

  setErrored(err) {
    this.#errored = err;
  }

  reject(taskErr) {
    _debugLog('[AsyncTask#reject()] args', {
      componentIdx: this.#componentIdx,
      taskID: this.#id,
      parentSubtask: this.#parentSubtask,
      parentSubtaskID: this.#parentSubtask?.id(),
      entryFnName: this.entryFnName(),
      callbackFnName: this.#callbackFnName,
      errMsg: taskErr.message,
    });

    if (this.isResolvedState() || this.#rejected) { return; }

    for (const subtask of this.#subtasks) {
      subtask.reject(taskErr);
    }

    this.#rejected = true;
    this.cancelRequested = true;
    this.#state = AsyncTask.State.PENDING_CANCEL;
    const cancelled = this.deliverPendingCancel({ cancellable: true });

    // TODO: do cleanup here to reset the machinery so we can run again?


    this.cancel({ error: taskErr });
  }

  resolve(results) {
    _debugLog('[AsyncTask#resolve()] args', {
      componentIdx: this.#componentIdx,
      taskID: this.#id,
      entryFnName: this.entryFnName(),
      callbackFnName: this.#callbackFnName,
    });

    if (this.#state === AsyncTask.State.RESOLVED) {
      throw new Error(`(component [${this.#componentIdx}]) task [${this.#id}]  is already resolved (did you forget to wait for an import?)`);
    }

    if (this.borrowedHandles.length > 0) {
      throw new Error('task still has borrow handles');
    }

    this.#state = AsyncTask.State.RESOLVED;

    switch (results.length) {
      case 0:
      this.onResolve(undefined);
      break;
      case 1:
      this.onResolve(results[0]);
      break;
      default:
      _debugLog('[AsyncTask#resolve()] unexpected number of results', {
        componentIdx: this.#componentIdx,
        results,
        taskID: this.#id,
        subtaskID: this.#parentSubtask?.id(),
        entryFnName: this.#entryFnName,
        callbackFnName: this.#callbackFnName,
      });
      throw new Error('unexpected number of results');
    }
  }

  exit() {
    _debugLog('[AsyncTask#exit()]', {
      componentIdx: this.#componentIdx,
      taskID: this.#id,
    });

    if (this.#exited)  { throw new Error("task has already exited"); }

    if (this.#state !== AsyncTask.State.RESOLVED) {
      // TODO(fix): only fused, manually specified post returns seem to break this invariant,
      // as the TaskReturn trampoline is not activated it seems.
      //
      // see: test/p3/ported/wasmtime/component-async/post-return.js
      //
      // We *should* be able to upgrade this to be more strict and throw at some point,
      // which may involve rewriting the upstream test to surface task return manually somehow.
      //
      //throw new Error(`(component [${this.#componentIdx}]) task [${this.#id}] exited without resolution`);
      _debugLog('[AsyncTask#exit()] task exited without resolution', {
        componentIdx: this.#componentIdx,
        taskID: this.#id,
        subtask: this.getParentSubtask(),
        subtaskID: this.getParentSubtask()?.id(),
      });
      this.#state = AsyncTask.State.RESOLVED;
    }

    if (this.borrowedHandles > 0) {
      throw new Error('task [${this.#id}] exited without clearing borrowed handles');
    }

    const state = getOrCreateAsyncState(this.#componentIdx);
    if (!state) { throw new Error('missing async state for component [' + this.#componentIdx + ']'); }

    // Exempt the host from exclusive lock check
    if (this.#componentIdx !== -1 && this.needsExclusiveLock() && !state.isExclusivelyLocked()) {
      throw new Error(`task [${this.#id}] exit: component [${this.#componentIdx}] should have been exclusively locked`);
    }

    state.exclusiveRelease();

    for (const f of this.#onExitHandlers) {
      try {
        f();
      } catch (err) {
        console.error("error during task exit handler", err);
        throw err;
      }
    }

    this.#exited = true;
    clearCurrentTask(this.#componentIdx, this.id());
  }

  needsExclusiveLock() {
    return !this.#isAsync || this.hasCallback();
  }

  createSubtask(args) {
    _debugLog('[AsyncTask#createSubtask()] args', args);
    const { componentIdx, childTask, callMetadata, fnName, isAsync, isManualAsync } = args;

    const cstate = getOrCreateAsyncState(this.#componentIdx);
    if (!cstate) {
      throw new Error(`invalid/missing async state for component idx [${componentIdx}]`);
    }

    const waitable = new Waitable({
      componentIdx: this.#componentIdx,
      target: `subtask (internal ID [${this.#id}])`,
    });

    const newSubtask = new AsyncSubtask({
      componentIdx,
      childTask,
      parentTask: this,
      callMetadata,
      isAsync,
      isManualAsync,
      fnName,
      waitable,
    });
    this.#subtasks.push(newSubtask);
    newSubtask.setTarget(`subtask (internal ID [${newSubtask.id()}], waitable [${waitable.idx()}], component [${componentIdx}])`);
    waitable.setIdx(cstate.handles.insert(newSubtask));
    waitable.setTarget(`waitable for subtask (waitable id [${waitable.idx()}], subtask internal ID [${newSubtask.id()}])`);

    return newSubtask;
  }

  getLatestSubtask() {
    return this.#subtasks.at(-1);
  }

  getSubtaskByWaitableRep(rep) {
    if (rep === undefined) { throw new TypeError('missing rep'); }
    return this.#subtasks.find(s => s.waitableRep() === rep);
  }

  currentSubtask() {
    _debugLog('[AsyncTask#currentSubtask()]');
    if (this.#subtasks.length === 0) { return undefined; }
    return this.#subtasks.at(-1);
  }

  removeSubtask(subtask) {
    if (this.#subtasks.length === 0) { throw new Error('cannot end current subtask: no current subtask'); }
    this.#subtasks = this.#subtasks.filter(t => t !== subtask);
    return subtask;
  }
}

const STREAMS = new RepTable({ target: 'global stream map' });
const ASYNC_STATE = new Map();

function getOrCreateAsyncState(componentIdx, init) {
  if (!ASYNC_STATE.has(componentIdx)) {
    const newState = new ComponentAsyncState({ componentIdx });
    ASYNC_STATE.set(componentIdx, newState);
  }
  return ASYNC_STATE.get(componentIdx);
}

class ComponentAsyncState {
  static EVENT_HANDLER_EVENTS = [ 'backpressure-change' ];

  #componentIdx;
  #callingAsyncImport = false;
  #syncImportWait = promiseWithResolvers();
  #locked = false;
  #parkedTasks = new Map();
  #suspendedTasksByTaskID = new Map();
  #suspendedTaskIDs = [];
  #errored = null;

  #backpressure = 0;
  #backpressureWaiters = 0n;

  #handlerMap = new Map();
  #nextHandlerID = 0n;

  #tickLoop = null;
  #tickLoopInterval = null;

  #onExclusiveReleaseHandlers = [];

  mayLeave = true;

  handles;
  subtasks;

  constructor(args) {
    this.#componentIdx = args.componentIdx;
    this.handles = new RepTable({ target: `component [${this.#componentIdx}] handles (waitable objects)` });
    this.subtasks = new RepTable({ target: `component [${this.#componentIdx}] subtasks` });
  };

  componentIdx() { return this.#componentIdx; }

  errored() { return this.#errored !== null; }
  setErrored(err) {
    _debugLog('[ComponentAsyncState#setErrored()] component errored', { err, componentIdx: this.#componentIdx });
    if (this.#errored) { return; }
    if (!err) {
      err = new Error('error elswehere (see other component instance error)')
      err.componentIdx = this.#componentIdx;
    }
    this.#errored = err;
  }

  callingSyncImport(val) {
    if (val === undefined) { return this.#callingAsyncImport; }
    if (typeof val !== 'boolean') { throw new TypeError('invalid setting for async import'); }
    const prev = this.#callingAsyncImport;
    this.#callingAsyncImport = val;
    if (prev === true && this.#callingAsyncImport === false) {
      this.#notifySyncImportEnd();
    }
  }

  #notifySyncImportEnd() {
    const existing = this.#syncImportWait;
    this.#syncImportWait = promiseWithResolvers();
    existing.resolve();
  }

  async waitForSyncImportCallEnd() {
    await this.#syncImportWait.promise;
  }

  setBackpressure(v) {
    this.#backpressure = v;
    return this.#backpressure
  }
  getBackpressure() { return this.#backpressure; }

  incrementBackpressure() {
    const current = this.#backpressure;
    if (current < 0 || current > 2**16) {
      throw new Error(`invalid current backpressure value [${current}]`);
    }
    const newValue = this.getBackpressure() + 1;
    if (newValue >= 2**16) {
      throw new Error(`invalid new backpressure value [${newValue}], overflow`);
    }
    return this.setBackpressure(newValue);
  }

  decrementBackpressure() {
    const current = this.#backpressure;
    if (current < 0 || current > 2**16) {
      throw new Error(`invalid current backpressure value [${current}]`);
    }
    const newValue = Math.max(0, current - 1);
    if (newValue < 0) {
      throw new Error(`invalid new backpressure value [${newValue}], underflow`);
    }
    return this.setBackpressure(newValue);
  }
  hasBackpressure() { return this.#backpressure > 0; }

  waitForBackpressure() {
    let backpressureCleared = false;
    const cstate = this;
    cstate.addBackpressureWaiter();
    const handlerID = this.registerHandler({
      event: 'backpressure-change',
      fn: (bp) => {
        if (bp === 0) {
          cstate.removeHandler(handlerID);
          backpressureCleared = true;
        }
      }
    });
    return new Promise((resolve) => {
      const interval = setInterval(() => {
        if (backpressureCleared) { return; }
        clearInterval(interval);
        cstate.removeBackpressureWaiter();
        resolve(null);
      }, 0);
    });
  }

  registerHandler(args) {
    const { event, fn } = args;
    if (!event) { throw new Error("missing handler event"); }
    if (!fn) { throw new Error("missing handler fn"); }

    if (!ComponentAsyncState.EVENT_HANDLER_EVENTS.includes(event)) {
      throw new Error(`unrecognized event handler [${event}]`);
    }

    const handlerID = this.#nextHandlerID++;
    let handlers = this.#handlerMap.get(event);
    if (!handlers) {
      handlers = [];
      this.#handlerMap.set(event, handlers)
    }

    handlers.push({ id: handlerID, fn, event });
    return handlerID;
  }

  removeHandler(args) {
    const { event, handlerID } = args;
    const registeredHandlers = this.#handlerMap.get(event);
    if (!registeredHandlers) { return; }
    const found = registeredHandlers.find(h => h.id === handlerID);
    if (!found) { return; }
    this.#handlerMap.set(event, this.#handlerMap.get(event).filter(h => h.id !== handlerID));
  }

  getBackpressureWaiters() { return this.#backpressureWaiters; }
  addBackpressureWaiter() { this.#backpressureWaiters++; }
  removeBackpressureWaiter() {
    this.#backpressureWaiters--;
    if (this.#backpressureWaiters < 0) {
      throw new Error("unexepctedly negative number of backpressure waiters");
    }
  }

  isExclusivelyLocked() { return this.#locked === true; }
  setLocked(locked) {
    this.#locked = locked;
  }

  // TODO(fix): we might want to check for pre-locked status here, we should be deterministically
  // going from locked -> unlocked and vice versa
  exclusiveLock() {
    _debugLog('[ComponentAsyncState#exclusiveLock()]', {
      locked: this.#locked,
      componentIdx: this.#componentIdx,
    });
    this.setLocked(true);
  }

  exclusiveRelease() {
    _debugLog('[ComponentAsyncState#exclusiveRelease()] args', {
      locked: this.#locked,
      componentIdx: this.#componentIdx,
    });
    this.setLocked(false);

    this.#onExclusiveReleaseHandlers = this.#onExclusiveReleaseHandlers.filter(v => !!v);
    for (const [idx, f] of this.#onExclusiveReleaseHandlers.entries()) {
      try {
        this.#onExclusiveReleaseHandlers[idx] = null;
        f();
      } catch (err) {
        _debugLog("error while executing handler for next exclusive release", err);
        throw err;
      }
    }
  }

  onNextExclusiveRelease(fn) {
    _debugLog('[ComponentAsyncState#()onNextExclusiveRelease] registering');
    this.#onExclusiveReleaseHandlers.push(fn);
  }

  #getSuspendedTaskMeta(taskID) {
    return this.#suspendedTasksByTaskID.get(taskID);
  }

  #removeSuspendedTaskMeta(taskID) {
    _debugLog('[ComponentAsyncState#removeSuspendedTaskMeta()] removing suspended task', { taskID });
    const idx = this.#suspendedTaskIDs.findIndex(t => t === taskID);
    const meta = this.#suspendedTasksByTaskID.get(taskID);
    this.#suspendedTaskIDs[idx] = null;
    this.#suspendedTasksByTaskID.delete(taskID);
    return meta;
  }

  #addSuspendedTaskMeta(meta) {
    if (!meta) { throw new Error('missing task meta'); }
    const taskID = meta.taskID;
    this.#suspendedTasksByTaskID.set(taskID, meta);
    this.#suspendedTaskIDs.push(taskID);
    if (this.#suspendedTasksByTaskID.size < this.#suspendedTaskIDs.length - 10) {
      this.#suspendedTaskIDs = this.#suspendedTaskIDs.filter(t => t !== null);
    }
  }

  // TODO(threads): readyFn is normally on the thread
  suspendTask(args) {
    const { task, readyFn } = args;
    const taskID = task.id();
    _debugLog('[ComponentAsyncState#suspendTask()]', {
      taskID,
      componentIdx: this.#componentIdx,
      taskEntryFnName: task.entryFnName(),
      subtask: task.getParentSubtask(),
    });

    if (this.#getSuspendedTaskMeta(taskID)) {
      throw new Error(`task [${taskID}] already suspended`);
    }

    const { promise, resolve, reject } = promiseWithResolvers();
    this.#addSuspendedTaskMeta({
      task,
      taskID,
      readyFn,
      resume: () => {
        _debugLog('[ComponentAsyncState#suspendTask()] resuming suspended task', { taskID });
        // TODO(threads): it's thread cancellation we should be checking for below, not task
        resolve(!task.isCancelled());
      },
    });

    this.runTickLoop();

    return promise;
  }

  resumeTaskByID(taskID) {
    const meta = this.#removeSuspendedTaskMeta(taskID);
    if (!meta) { return; }
    if (meta.taskID !== taskID) { throw new Error('task ID does not match'); }
    meta.resume();
  }

  async runTickLoop() {
    if (this.#tickLoop !== null) { return; }
    this.#tickLoop = 1;
    setTimeout(async () => {
      let done = this.tick();
      while (!done) {
        await new Promise((resolve) => setTimeout(resolve, 30));
        done = this.tick();
      }
      this.#tickLoop = null;
    }, 10);
  }

  tick() {
    // _debugLog('[ComponentAsyncState#tick()]', { suspendedTaskIDs: this.#suspendedTaskIDs });

    const resumableTasks = this.#suspendedTaskIDs.filter(t => t !== null);
    for (const taskID of resumableTasks) {
      const meta = this.#suspendedTasksByTaskID.get(taskID);
      if (!meta || !meta.readyFn) {
        throw new Error(`missing/invalid task despite ID [${taskID}] being present`);
      }

      // If the task failed via any means, allow the task to resume because
      // it's been cancelled -- the callback should immediately exit as well
      if (meta.task.isRejected()) {
        _debugLog('[ComponentAsyncState#suspendTask()] detected task rejection, leaving early', { meta });
        this.resumeTaskByID(taskID);
        return;
      }

      const isReady = meta.readyFn();
      if (!isReady) { continue; }

      this.resumeTaskByID(taskID);
    }

    return this.#suspendedTaskIDs.filter(t => t !== null).length === 0;
  }

  addStreamEndToTable(args) {
    _debugLog('[ComponentAsyncState#addStreamEnd()] args', args);
    const { tableIdx, streamEnd } = args;
    if (typeof streamEnd === 'number') { throw new Error("INSERTING BAD STREAMEND"); }

    let { table, componentIdx } = STREAM_TABLES[tableIdx];
    if (componentIdx === undefined || !table) {
      throw new Error(`invalid global stream table state for table [${tableIdx}]`);
    }

    const handle = table.insert(streamEnd);
    streamEnd.setHandle(handle);
    streamEnd.setStreamTableIdx(tableIdx);

    const cstate = getOrCreateAsyncState(componentIdx);
    const waitableIdx = cstate.handles.insert(streamEnd);
    streamEnd.setWaitableIdx(waitableIdx);

    _debugLog('[ComponentAsyncState#addStreamEnd()] added stream end', {
      tableIdx,
      table,
      handle,
      streamEnd,
      destComponentIdx: componentIdx,
    });

    return { handle, waitableIdx };
  }

  createWaitable(args) {
    return new Waitable({ target: args?.target, });
  }

  createStream(args) {
    _debugLog('[ComponentAsyncState#createStream()] args', args);
    const { tableIdx, elemMeta } = args;
    if (tableIdx === undefined) { throw new Error("missing table idx while adding stream"); }
    if (elemMeta === undefined) { throw new Error("missing element metadata while adding stream"); }

    const { table: localStreamTable, componentIdx } = STREAM_TABLES[tableIdx];
    if (!localStreamTable) {
      throw new Error(`missing global stream table lookup for table [${tableIdx}] while creating stream`);
    }
    if (componentIdx !== this.#componentIdx) {
      throw new Error('component idx mismatch while creating stream');
    }

    const readWaitable = this.createWaitable();
    const writeWaitable = this.createWaitable();

    const stream = new InternalStream({
      tableIdx,
      componentIdx: this.#componentIdx,
      elemMeta,
      readWaitable,
      writeWaitable,
    });
    stream.setGlobalStreamMapRep(STREAMS.insert(stream));

    const writeEnd = stream.writeEnd();
    writeEnd.setWaitableIdx(this.handles.insert(writeEnd));
    writeEnd.setHandle(localStreamTable.insert(writeEnd));
    if (writeEnd.streamTableIdx() !== tableIdx) { throw new Error("unexpectedly mismatched stream table"); }

    const writeEndWaitableIdx = writeEnd.waitableIdx();
    const writeEndHandle = writeEnd.handle();
    writeWaitable.setTarget(`waitable for stream write end (waitable [${writeEndWaitableIdx}])`);
    writeEnd.setTarget(`stream write end (waitable [${writeEndWaitableIdx}])`);

    const readEnd = stream.readEnd();
    readEnd.setWaitableIdx(this.handles.insert(readEnd));
    readEnd.setHandle(localStreamTable.insert(readEnd));
    if (readEnd.streamTableIdx() !== tableIdx) { throw new Error("unexpectedly mismatched stream table"); }

    const readEndWaitableIdx = readEnd.waitableIdx();
    const readEndHandle = readEnd.handle();
    readWaitable.setTarget(`waitable for read end (waitable [${readEndWaitableIdx}])`);
    readEnd.setTarget(`stream read end (waitable [${readEndWaitableIdx}])`);

    return {
      writeEndWaitableIdx,
      writeEndHandle,
      readEndWaitableIdx,
      readEndHandle,
    };
  }

  getStreamEnd(args) {
    _debugLog('[ComponentAsyncState#getStreamEnd()] args', args);
    const { tableIdx, streamEndHandle, streamEndWaitableIdx } = args;
    if (tableIdx === undefined) { throw new Error('missing table idx while getting stream end'); }

    const { table, componentIdx } = STREAM_TABLES[tableIdx];
    const cstate = getOrCreateAsyncState(componentIdx);

    let streamEnd;
    if (streamEndWaitableIdx !== undefined) {
      streamEnd = cstate.handles.get(streamEndWaitableIdx);
    } else if (streamEndHandle !== undefined) {
      if (!table) { throw new Error(`missing/invalid table [${tableIdx}] while getting stream end`); }
      streamEnd = table.get(streamEndHandle);
    } else {
      throw new TypeError("must specify either waitable idx or handle to retrieve stream");
    }

    if (!streamEnd) {
      throw new Error(`missing stream end (tableIdx [${tableIdx}], handle [${streamEndHandle}], waitableIdx [${streamEndWaitableIdx}])`);
    }
    if (tableIdx && streamEnd.streamTableIdx() !== tableIdx) {
      throw new Error(`stream end table idx [${streamEnd.streamTableIdx()}] does not match [${tableIdx}]`);
    }

    return streamEnd;
  }

  deleteStreamEnd(args) {
    _debugLog('[ComponentAsyncState#deleteStreamEnd()] args', args);
    const { tableIdx, streamEndWaitableIdx } = args;
    if (tableIdx === undefined) { throw new Error("missing table idx while removing stream end"); }
    if (streamEndWaitableIdx === undefined) { throw new Error("missing stream idx while removing stream end"); }

    const { table, componentIdx } = STREAM_TABLES[tableIdx];
    const cstate = getOrCreateAsyncState(componentIdx);

    const streamEnd = cstate.handles.get(streamEndWaitableIdx);
    if (!streamEnd) {
      throw new Error(`missing stream end [${streamEndWaitableIdx}] in component handles while deleting stream`);
    }
    if (streamEnd.streamTableIdx() !== tableIdx) {
      throw new Error(`stream end table idx [${streamEnd.streamTableIdx()}] does not match [${tableIdx}]`);
    }

    let removed = cstate.handles.remove(streamEnd.waitableIdx());
    if (!removed) {
      throw new Error(`failed to remove stream end [${streamEndWaitableIdx}] waitable obj in component [${componentIdx}]`);
    }

    removed = table.remove(streamEnd.handle());
    if (!removed) {
      throw new Error(`failed to remove stream end with handle [${streamEnd.handle()}] from stream table [${tableIdx}] in component [${componentIdx}]`);
    }

    return streamEnd;
  }

  removeStreamEndFromTable(args) {
    _debugLog('[ComponentAsyncState#removeStreamEndFromTable()] args', args);

    const { tableIdx, streamWaitableIdx } = args;
    if (tableIdx === undefined) { throw new Error("missing table idx while removing stream end"); }
    if (streamWaitableIdx === undefined) {
      throw new Error("missing stream end waitable idx while removing stream end");
    }

    const { table, componentIdx } = STREAM_TABLES[tableIdx];
    if (!table) { throw new Error(`missing/invalid table [${tableIdx}] while removing stream end`); }

    const cstate = getOrCreateAsyncState(componentIdx);

    const streamEnd = cstate.handles.get(streamWaitableIdx);
    if (!streamEnd) {
      throw new Error(`missing stream end (handle [${streamWaitableIdx}], table [${tableIdx}])`);
    }
    const handle = streamEnd.handle();

    let removed = cstate.handles.remove(streamWaitableIdx);
    if (!removed) {
      throw new Error(`failed to remove streamEnd from handles (waitable idx [${streamWaitableIdx}]), component [${componentIdx}])`);
    }

    removed = table.remove(handle);
    if (!removed) {
      throw new Error(`failed to remove streamEnd from table (handle [${handle}]), table [${tableIdx}], component [${componentIdx}])`);
    }

    return streamEnd;
  }
}

const isNode = typeof process !== 'undefined' && process.versions && process.versions.node;
let _fs;
async function fetchCompile (url) {
  if (isNode) {
    _fs = _fs || await import('node:fs/promises');
    return WebAssembly.compile(await _fs.readFile(url));
  }
  return fetch(url).then(WebAssembly.compileStreaming);
}

class ComponentError extends Error {
  constructor (value) {
    const enumerable = typeof value !== 'string';
    super(enumerable ? `${String(value)} (see error.payload)` : value);
    Object.defineProperty(this, 'payload', { value, enumerable });
  }
}

const instantiateCore = WebAssembly.instantiate;


let exports0;
let memory0;
let realloc0;
let realloc0Async;
let postReturn0;
let postReturn0Async;
let postReturn1;
let postReturn1Async;
let engineCreateVillage;

function createVillage(arg0, arg1) {
  var vec6 = arg0;
  var len6 = vec6.length;
  var result6 = realloc0(0, 0, 4, len6 * 12);
  for (let i = 0; i < vec6.length; i++) {
    const e = vec6[i];
    const base = result6 + i * 12;var {roleType: v0_0, opts: v0_1 } = e;
    var val1 = v0_0;
    let enum1;
    switch (val1) {
      case 'villager': {
        enum1 = 0;
        break;
      }
      case 'seer': {
        enum1 = 1;
        break;
      }
      case 'bodyguard': {
        enum1 = 2;
        break;
      }
      case 'wolf': {
        enum1 = 3;
        break;
      }
      case 'madman': {
        enum1 = 4;
        break;
      }
      case 'lover': {
        enum1 = 5;
        break;
      }
      case 'bitch': {
        enum1 = 6;
        break;
      }
      case 'medium': {
        enum1 = 7;
        break;
      }
      case 'hamster': {
        enum1 = 8;
        break;
      }
      default: {
        if ((v0_0) instanceof Error) {
          console.error(v0_0);
        }

        throw new TypeError(`"${val1}" is not one of the cases of role-type`);
      }
    }
    dataView(memory0).setInt8(base + 0, enum1, true);
    var vec5 = v0_1;
    var len5 = vec5.length;
    var result5 = realloc0(0, 0, 4, len5 * 16);
    for (let i = 0; i < vec5.length; i++) {
      const e = vec5[i];
      const base = result5 + i * 16;var [tuple2_0, tuple2_1] = e;

      var encodeRes = _utf8AllocateAndEncode(tuple2_0, realloc0, memory0);
      var ptr3= encodeRes.ptr;
      var len3 = encodeRes.len;

      dataView(memory0).setUint32(base + 4, len3, true);
      dataView(memory0).setUint32(base + 0, ptr3, true);

      var encodeRes = _utf8AllocateAndEncode(tuple2_1, realloc0, memory0);
      var ptr4= encodeRes.ptr;
      var len4 = encodeRes.len;

      dataView(memory0).setUint32(base + 12, len4, true);
      dataView(memory0).setUint32(base + 8, ptr4, true);
    }
    dataView(memory0).setUint32(base + 8, len5, true);
    dataView(memory0).setUint32(base + 4, result5, true);
  }
  var {vote: v7_0 } = arg1;
  var variant8 = v7_0;
  let variant8_0;
  switch (variant8.tag) {
    case 'public': {
      variant8_0 = 0;
      break;
    }
    case 'private': {
      variant8_0 = 1;
      break;
    }
    default: {
      throw new TypeError(`invalid variant tag value \`${JSON.stringify(variant8.tag)}\` (received \`${variant8}\`) specified for \`VoteRule\``);
    }
  }
  _debugLog('[iface="kuboon:jinro/engine", function="create-village"][Instruction::CallWasm] enter', {
    funcName: 'create-village',
    paramCount: 3,
    async: false,
    postReturn: true,
  });
  const hostProvided = false;

  const [task, _wasm_call_currentTaskID] = createNewCurrentTask({
    componentIdx: 0,
    isAsync: false,
    isManualAsync: false,
    entryFnName: 'engineCreateVillage',
    getCallbackFn: () => null,
    callbackFnName: 'null',
    errHandling: 'throw-result-err',
    callingWasmExport: true,
  });

  const started = task.enterSync();
  task.setReturnMemoryIdx(0);
  task.setReturnMemory(memory0);
  let ret =   _withGlobalCurrentTaskMeta({
    taskID: task.id(),
    componentIdx: task.componentIdx(),
    fn: () => engineCreateVillage(result6, len6, variant8_0),
  });

  let variant50;
  switch (dataView(memory0).getUint8(ret + 0, true)) {
    case 0: {
      let variant9;
      switch (dataView(memory0).getUint8(ret + 4, true)) {
        case 0: {
          variant9= {
            tag: 'public',
          };
          break;
        }
        case 1: {
          variant9= {
            tag: 'private',
          };
          break;
        }
        default: {
          throw new TypeError('invalid variant discriminant for VoteRule');
        }
      }
      var len15 = dataView(memory0).getUint32(ret + 12, true);
      var base15 = dataView(memory0).getUint32(ret + 8, true);
      var result15 = [];
      for (let i = 0; i < len15; i++) {
        const base = base15 + i * 20;
        var ptr10 = dataView(memory0).getUint32(base + 0, true);
        var len10 = dataView(memory0).getUint32(base + 4, true);
        var result10 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr10, len10));
        let enum11;
        switch (dataView(memory0).getUint8(base + 8, true)) {
          case 0: {
            enum11 = 'villager';
            break;
          }
          case 1: {
            enum11 = 'seer';
            break;
          }
          case 2: {
            enum11 = 'bodyguard';
            break;
          }
          case 3: {
            enum11 = 'wolf';
            break;
          }
          case 4: {
            enum11 = 'madman';
            break;
          }
          case 5: {
            enum11 = 'lover';
            break;
          }
          case 6: {
            enum11 = 'bitch';
            break;
          }
          case 7: {
            enum11 = 'medium';
            break;
          }
          case 8: {
            enum11 = 'hamster';
            break;
          }
          default: {
            throw new TypeError('invalid discriminant specified for RoleType');
          }
        }
        var len14 = dataView(memory0).getUint32(base + 16, true);
        var base14 = dataView(memory0).getUint32(base + 12, true);
        var result14 = [];
        for (let i = 0; i < len14; i++) {
          const base = base14 + i * 16;
          var ptr12 = dataView(memory0).getUint32(base + 0, true);
          var len12 = dataView(memory0).getUint32(base + 4, true);
          var result12 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr12, len12));
          var ptr13 = dataView(memory0).getUint32(base + 8, true);
          var len13 = dataView(memory0).getUint32(base + 12, true);
          var result13 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr13, len13));
          result14.push([result12, result13]);
        }
        result15.push({
          id: result10,
          role: {
            roleType: enum11,
            opts: result14,
          },
        });
      }
      var len33 = dataView(memory0).getUint32(ret + 20, true);
      var base33 = dataView(memory0).getUint32(ret + 16, true);
      var result33 = [];
      for (let i = 0; i < len33; i++) {
        const base = base33 + i * 20;
        var len20 = dataView(memory0).getUint32(base + 8, true);
        var base20 = dataView(memory0).getUint32(base + 4, true);
        var result20 = [];
        for (let i = 0; i < len20; i++) {
          const base = base20 + i * 24;
          var ptr16 = dataView(memory0).getUint32(base + 0, true);
          var len16 = dataView(memory0).getUint32(base + 4, true);
          var result16 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr16, len16));
          let enum17;
          switch (dataView(memory0).getUint8(base + 8, true)) {
            case 0: {
              enum17 = 'vote';
              break;
            }
            case 1: {
              enum17 = 'bite';
              break;
            }
            case 2: {
              enum17 = 'divine';
              break;
            }
            case 3: {
              enum17 = 'medium';
              break;
            }
            case 4: {
              enum17 = 'guard';
              break;
            }
            case 5: {
              enum17 = 'hamster-curse';
              break;
            }
            case 6: {
              enum17 = 'love';
              break;
            }
            case 7: {
              enum17 = 'lovers-suicide';
              break;
            }
            case 8: {
              enum17 = 'fake-love';
              break;
            }
            case 9: {
              enum17 = 'unknown';
              break;
            }
            default: {
              throw new TypeError('invalid discriminant specified for ActionType');
            }
          }
          let variant19;
          switch (dataView(memory0).getUint8(base + 12, true)) {
            case 0: {
              variant19 = undefined;
              break;
            }
            case 1: {
              var ptr18 = dataView(memory0).getUint32(base + 16, true);
              var len18 = dataView(memory0).getUint32(base + 20, true);
              var result18 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr18, len18));
              variant19 = result18;
              break;
            }
            default: {
              throw new TypeError('invalid variant discriminant for option');
            }
          }
          result20.push({
            actor: result16,
            actionType: enum17,
            target: variant19,
          });
        }
        var len32 = dataView(memory0).getUint32(base + 16, true);
        var base32 = dataView(memory0).getUint32(base + 12, true);
        var result32 = [];
        for (let i = 0; i < len32; i++) {
          const base = base32 + i * 52;
          var ptr21 = dataView(memory0).getUint32(base + 0, true);
          var len21 = dataView(memory0).getUint32(base + 4, true);
          var result21 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr21, len21));
          let variant24;
          switch (dataView(memory0).getUint8(base + 8, true)) {
            case 0: {
              variant24= {
                tag: 'all',
              };
              break;
            }
            case 1: {
              variant24= {
                tag: 'afterall',
              };
              break;
            }
            case 2: {
              var len23 = dataView(memory0).getUint32(base + 16, true);
              var base23 = dataView(memory0).getUint32(base + 12, true);
              var result23 = [];
              for (let i = 0; i < len23; i++) {
                const base = base23 + i * 8;
                var ptr22 = dataView(memory0).getUint32(base + 0, true);
                var len22 = dataView(memory0).getUint32(base + 4, true);
                var result22 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr22, len22));
                result23.push(result22);
              }
              variant24= {
                tag: 'only',
                val: result23
              };
              break;
            }
            default: {
              throw new TypeError('invalid variant discriminant for Receivers');
            }
          }
          let enum25;
          switch (dataView(memory0).getUint8(base + 20, true)) {
            case 0: {
              enum25 = 'vote';
              break;
            }
            case 1: {
              enum25 = 'bite';
              break;
            }
            case 2: {
              enum25 = 'divine';
              break;
            }
            case 3: {
              enum25 = 'medium';
              break;
            }
            case 4: {
              enum25 = 'guard';
              break;
            }
            case 5: {
              enum25 = 'hamster-curse';
              break;
            }
            case 6: {
              enum25 = 'love';
              break;
            }
            case 7: {
              enum25 = 'lovers-suicide';
              break;
            }
            case 8: {
              enum25 = 'fake-love';
              break;
            }
            case 9: {
              enum25 = 'unknown';
              break;
            }
            default: {
              throw new TypeError('invalid discriminant specified for ActionType');
            }
          }
          let variant27;
          switch (dataView(memory0).getUint8(base + 24, true)) {
            case 0: {
              variant27 = undefined;
              break;
            }
            case 1: {
              var ptr26 = dataView(memory0).getUint32(base + 28, true);
              var len26 = dataView(memory0).getUint32(base + 32, true);
              var result26 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr26, len26));
              variant27 = result26;
              break;
            }
            default: {
              throw new TypeError('invalid variant discriminant for option');
            }
          }
          let variant29;
          switch (dataView(memory0).getUint8(base + 36, true)) {
            case 0: {
              variant29 = undefined;
              break;
            }
            case 1: {
              var ptr28 = dataView(memory0).getUint32(base + 40, true);
              var len28 = dataView(memory0).getUint32(base + 44, true);
              var result28 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr28, len28));
              variant29 = result28;
              break;
            }
            default: {
              throw new TypeError('invalid variant discriminant for option');
            }
          }
          let variant31;
          switch (dataView(memory0).getUint8(base + 48, true)) {
            case 0: {
              variant31 = undefined;
              break;
            }
            case 1: {
              let variant30;
              switch (dataView(memory0).getUint8(base + 49, true)) {
                case 0: {
                  variant30= {
                    tag: 'dead',
                  };
                  break;
                }
                case 1: {
                  variant30= {
                    tag: 'guarded',
                  };
                  break;
                }
                case 2: {
                  variant30= {
                    tag: 'partnered',
                  };
                  break;
                }
                case 3: {
                  variant30= {
                    tag: 'wolf',
                  };
                  break;
                }
                case 4: {
                  variant30= {
                    tag: 'non-wolf',
                  };
                  break;
                }
                default: {
                  throw new TypeError('invalid variant discriminant for LogResult');
                }
              }
              variant31 = variant30;
              break;
            }
            default: {
              throw new TypeError('invalid variant discriminant for option');
            }
          }
          result32.push({
            id: result21,
            receivers: variant24,
            actionType: enum25,
            actor: variant27,
            target: variant29,
            logResult: variant31,
          });
        }
        result33.push({
          dayNumber: dataView(memory0).getInt32(base + 0, true),
          actions: result20,
          logs: result32,
        });
      }
      let variant35;
      switch (dataView(memory0).getUint8(ret + 28, true)) {
        case 0: {
          variant35 = undefined;
          break;
        }
        case 1: {
          let enum34;
          switch (dataView(memory0).getUint8(ret + 29, true)) {
            case 0: {
              enum34 = 'villagers';
              break;
            }
            case 1: {
              enum34 = 'wolves';
              break;
            }
            case 2: {
              enum34 = 'hamsters';
              break;
            }
            case 3: {
              enum34 = 'lovers';
              break;
            }
            default: {
              throw new TypeError('invalid discriminant specified for Team');
            }
          }
          variant35 = enum34;
          break;
        }
        default: {
          throw new TypeError('invalid variant discriminant for option');
        }
      }
      var len47 = dataView(memory0).getUint32(ret + 36, true);
      var base47 = dataView(memory0).getUint32(ret + 32, true);
      var result47 = [];
      for (let i = 0; i < len47; i++) {
        const base = base47 + i * 32;
        var ptr36 = dataView(memory0).getUint32(base + 0, true);
        var len36 = dataView(memory0).getUint32(base + 4, true);
        var result36 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr36, len36));
        let enum37;
        switch (dataView(memory0).getUint8(base + 8, true)) {
          case 0: {
            enum37 = 'villager';
            break;
          }
          case 1: {
            enum37 = 'seer';
            break;
          }
          case 2: {
            enum37 = 'bodyguard';
            break;
          }
          case 3: {
            enum37 = 'wolf';
            break;
          }
          case 4: {
            enum37 = 'madman';
            break;
          }
          case 5: {
            enum37 = 'lover';
            break;
          }
          case 6: {
            enum37 = 'bitch';
            break;
          }
          case 7: {
            enum37 = 'medium';
            break;
          }
          case 8: {
            enum37 = 'hamster';
            break;
          }
          default: {
            throw new TypeError('invalid discriminant specified for RoleType');
          }
        }
        let enum38;
        switch (dataView(memory0).getUint8(base + 9, true)) {
          case 0: {
            enum38 = 'villagers';
            break;
          }
          case 1: {
            enum38 = 'wolves';
            break;
          }
          case 2: {
            enum38 = 'hamsters';
            break;
          }
          case 3: {
            enum38 = 'lovers';
            break;
          }
          default: {
            throw new TypeError('invalid discriminant specified for Team');
          }
        }
        var len42 = dataView(memory0).getUint32(base + 16, true);
        var base42 = dataView(memory0).getUint32(base + 12, true);
        var result42 = [];
        for (let i = 0; i < len42; i++) {
          const base = base42 + i * 12;
          let enum39;
          switch (dataView(memory0).getUint8(base + 0, true)) {
            case 0: {
              enum39 = 'vote';
              break;
            }
            case 1: {
              enum39 = 'bite';
              break;
            }
            case 2: {
              enum39 = 'divine';
              break;
            }
            case 3: {
              enum39 = 'medium';
              break;
            }
            case 4: {
              enum39 = 'guard';
              break;
            }
            case 5: {
              enum39 = 'hamster-curse';
              break;
            }
            case 6: {
              enum39 = 'love';
              break;
            }
            case 7: {
              enum39 = 'lovers-suicide';
              break;
            }
            case 8: {
              enum39 = 'fake-love';
              break;
            }
            case 9: {
              enum39 = 'unknown';
              break;
            }
            default: {
              throw new TypeError('invalid discriminant specified for ActionType');
            }
          }
          var len41 = dataView(memory0).getUint32(base + 8, true);
          var base41 = dataView(memory0).getUint32(base + 4, true);
          var result41 = [];
          for (let i = 0; i < len41; i++) {
            const base = base41 + i * 8;
            var ptr40 = dataView(memory0).getUint32(base + 0, true);
            var len40 = dataView(memory0).getUint32(base + 4, true);
            var result40 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr40, len40));
            result41.push(result40);
          }
          result42.push({
            actionType: enum39,
            targets: result41,
          });
        }
        let variant44;
        switch (dataView(memory0).getUint8(base + 20, true)) {
          case 0: {
            variant44 = undefined;
            break;
          }
          case 1: {
            let enum43;
            switch (dataView(memory0).getUint8(base + 21, true)) {
              case 0: {
                enum43 = 'executed';
                break;
              }
              case 1: {
                enum43 = 'found-dead';
                break;
              }
              default: {
                throw new TypeError('invalid discriminant specified for CauseOfDeath');
              }
            }
            variant44 = enum43;
            break;
          }
          default: {
            throw new TypeError('invalid variant discriminant for option');
          }
        }
        var len46 = dataView(memory0).getUint32(base + 28, true);
        var base46 = dataView(memory0).getUint32(base + 24, true);
        var result46 = [];
        for (let i = 0; i < len46; i++) {
          const base = base46 + i * 8;
          var ptr45 = dataView(memory0).getUint32(base + 0, true);
          var len45 = dataView(memory0).getUint32(base + 4, true);
          var result45 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr45, len45));
          result46.push(result45);
        }
        result47.push({
          id: result36,
          roleType: enum37,
          team: enum38,
          availableActions: result42,
          causeOfDeath: variant44,
          logIds: result46,
        });
      }
      variant50= {
        tag: 'ok',
        val: [{
          rule: {
            vote: variant9,
          },
          creatures: result15,
          days: result33,
        }, {
          dayNumber: dataView(memory0).getInt32(ret + 24, true),
          winner: variant35,
          creatureStatuses: result47,
        }]
      };
      break;
    }
    case 1: {
      let variant49;
      switch (dataView(memory0).getUint8(ret + 4, true)) {
        case 0: {
          var ptr48 = dataView(memory0).getUint32(ret + 8, true);
          var len48 = dataView(memory0).getUint32(ret + 12, true);
          var result48 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr48, len48));
          variant49= {
            tag: 'data-error',
            val: result48
          };
          break;
        }
        default: {
          throw new TypeError('invalid variant discriminant for DataError');
        }
      }
      variant50= {
        tag: 'err',
        val: variant49
      };
      break;
    }
    default: {
      throw new TypeError('invalid variant discriminant for expected');
    }
  }
  _debugLog('[iface="kuboon:jinro/engine", function="create-village"][Instruction::Return]', {
    funcName: 'create-village',
    paramCount: 1,
    async: false,
    postReturn: true
  });
  const retCopy = variant50;
  task.resolve([retCopy.val]);

  let cstate = getOrCreateAsyncState(0);
  cstate.mayLeave = false;
  postReturn0(ret);
  cstate.mayLeave = true;
  task.exit();



  if (typeof retCopy === 'object' && retCopy.tag === 'err') {
    throw new ComponentError(retCopy.val);
  }
  return retCopy.val;

}
let engineProcessDay;

function processDay(arg0, arg1) {
  var {rule: v0_0, creatures: v0_1, days: v0_2 } = arg0;
  var {vote: v1_0 } = v0_0;
  var variant2 = v1_0;
  let variant2_0;
  switch (variant2.tag) {
    case 'public': {
      variant2_0 = 0;
      break;
    }
    case 'private': {
      variant2_0 = 1;
      break;
    }
    default: {
      throw new TypeError(`invalid variant tag value \`${JSON.stringify(variant2.tag)}\` (received \`${variant2}\`) specified for \`VoteRule\``);
    }
  }
  var vec11 = v0_1;
  var len11 = vec11.length;
  var result11 = realloc0(0, 0, 4, len11 * 20);
  for (let i = 0; i < vec11.length; i++) {
    const e = vec11[i];
    const base = result11 + i * 20;var {id: v3_0, role: v3_1 } = e;

    var encodeRes = _utf8AllocateAndEncode(v3_0, realloc0, memory0);
    var ptr4= encodeRes.ptr;
    var len4 = encodeRes.len;

    dataView(memory0).setUint32(base + 4, len4, true);
    dataView(memory0).setUint32(base + 0, ptr4, true);
    var {roleType: v5_0, opts: v5_1 } = v3_1;
    var val6 = v5_0;
    let enum6;
    switch (val6) {
      case 'villager': {
        enum6 = 0;
        break;
      }
      case 'seer': {
        enum6 = 1;
        break;
      }
      case 'bodyguard': {
        enum6 = 2;
        break;
      }
      case 'wolf': {
        enum6 = 3;
        break;
      }
      case 'madman': {
        enum6 = 4;
        break;
      }
      case 'lover': {
        enum6 = 5;
        break;
      }
      case 'bitch': {
        enum6 = 6;
        break;
      }
      case 'medium': {
        enum6 = 7;
        break;
      }
      case 'hamster': {
        enum6 = 8;
        break;
      }
      default: {
        if ((v5_0) instanceof Error) {
          console.error(v5_0);
        }

        throw new TypeError(`"${val6}" is not one of the cases of role-type`);
      }
    }
    dataView(memory0).setInt8(base + 8, enum6, true);
    var vec10 = v5_1;
    var len10 = vec10.length;
    var result10 = realloc0(0, 0, 4, len10 * 16);
    for (let i = 0; i < vec10.length; i++) {
      const e = vec10[i];
      const base = result10 + i * 16;var [tuple7_0, tuple7_1] = e;

      var encodeRes = _utf8AllocateAndEncode(tuple7_0, realloc0, memory0);
      var ptr8= encodeRes.ptr;
      var len8 = encodeRes.len;

      dataView(memory0).setUint32(base + 4, len8, true);
      dataView(memory0).setUint32(base + 0, ptr8, true);

      var encodeRes = _utf8AllocateAndEncode(tuple7_1, realloc0, memory0);
      var ptr9= encodeRes.ptr;
      var len9 = encodeRes.len;

      dataView(memory0).setUint32(base + 12, len9, true);
      dataView(memory0).setUint32(base + 8, ptr9, true);
    }
    dataView(memory0).setUint32(base + 16, len10, true);
    dataView(memory0).setUint32(base + 12, result10, true);
  }
  var vec32 = v0_2;
  var len32 = vec32.length;
  var result32 = realloc0(0, 0, 4, len32 * 20);
  for (let i = 0; i < vec32.length; i++) {
    const e = vec32[i];
    const base = result32 + i * 20;var {dayNumber: v12_0, actions: v12_1, logs: v12_2 } = e;
    dataView(memory0).setInt32(base + 0, toInt32(v12_0), true);
    var vec18 = v12_1;
    var len18 = vec18.length;
    var result18 = realloc0(0, 0, 4, len18 * 24);
    for (let i = 0; i < vec18.length; i++) {
      const e = vec18[i];
      const base = result18 + i * 24;var {actor: v13_0, actionType: v13_1, target: v13_2 } = e;

      var encodeRes = _utf8AllocateAndEncode(v13_0, realloc0, memory0);
      var ptr14= encodeRes.ptr;
      var len14 = encodeRes.len;

      dataView(memory0).setUint32(base + 4, len14, true);
      dataView(memory0).setUint32(base + 0, ptr14, true);
      var val15 = v13_1;
      let enum15;
      switch (val15) {
        case 'vote': {
          enum15 = 0;
          break;
        }
        case 'bite': {
          enum15 = 1;
          break;
        }
        case 'divine': {
          enum15 = 2;
          break;
        }
        case 'medium': {
          enum15 = 3;
          break;
        }
        case 'guard': {
          enum15 = 4;
          break;
        }
        case 'hamster-curse': {
          enum15 = 5;
          break;
        }
        case 'love': {
          enum15 = 6;
          break;
        }
        case 'lovers-suicide': {
          enum15 = 7;
          break;
        }
        case 'fake-love': {
          enum15 = 8;
          break;
        }
        case 'unknown': {
          enum15 = 9;
          break;
        }
        default: {
          if ((v13_1) instanceof Error) {
            console.error(v13_1);
          }

          throw new TypeError(`"${val15}" is not one of the cases of action-type`);
        }
      }
      dataView(memory0).setInt8(base + 8, enum15, true);
      var variant17 = v13_2;
      if (variant17 === null || variant17=== undefined) {
        dataView(memory0).setInt8(base + 12, 0, true);
      } else {
        const e = variant17;
        dataView(memory0).setInt8(base + 12, 1, true);

        var encodeRes = _utf8AllocateAndEncode(e, realloc0, memory0);
        var ptr16= encodeRes.ptr;
        var len16 = encodeRes.len;

        dataView(memory0).setUint32(base + 20, len16, true);
        dataView(memory0).setUint32(base + 16, ptr16, true);
      }
    }
    dataView(memory0).setUint32(base + 8, len18, true);
    dataView(memory0).setUint32(base + 4, result18, true);
    var vec31 = v12_2;
    var len31 = vec31.length;
    var result31 = realloc0(0, 0, 4, len31 * 52);
    for (let i = 0; i < vec31.length; i++) {
      const e = vec31[i];
      const base = result31 + i * 52;var {id: v19_0, receivers: v19_1, actionType: v19_2, actor: v19_3, target: v19_4, logResult: v19_5 } = e;

      var encodeRes = _utf8AllocateAndEncode(v19_0, realloc0, memory0);
      var ptr20= encodeRes.ptr;
      var len20 = encodeRes.len;

      dataView(memory0).setUint32(base + 4, len20, true);
      dataView(memory0).setUint32(base + 0, ptr20, true);
      var variant23 = v19_1;
      switch (variant23.tag) {
        case 'all': {
          dataView(memory0).setInt8(base + 8, 0, true);
          break;
        }
        case 'afterall': {
          dataView(memory0).setInt8(base + 8, 1, true);
          break;
        }
        case 'only': {
          const e = variant23.val;
          dataView(memory0).setInt8(base + 8, 2, true);
          var vec22 = e;
          var len22 = vec22.length;
          var result22 = realloc0(0, 0, 4, len22 * 8);
          for (let i = 0; i < vec22.length; i++) {
            const e = vec22[i];
            const base = result22 + i * 8;
            var encodeRes = _utf8AllocateAndEncode(e, realloc0, memory0);
            var ptr21= encodeRes.ptr;
            var len21 = encodeRes.len;

            dataView(memory0).setUint32(base + 4, len21, true);
            dataView(memory0).setUint32(base + 0, ptr21, true);
          }
          dataView(memory0).setUint32(base + 16, len22, true);
          dataView(memory0).setUint32(base + 12, result22, true);
          break;
        }
        default: {
          throw new TypeError(`invalid variant tag value \`${JSON.stringify(variant23.tag)}\` (received \`${variant23}\`) specified for \`Receivers\``);
        }
      }
      var val24 = v19_2;
      let enum24;
      switch (val24) {
        case 'vote': {
          enum24 = 0;
          break;
        }
        case 'bite': {
          enum24 = 1;
          break;
        }
        case 'divine': {
          enum24 = 2;
          break;
        }
        case 'medium': {
          enum24 = 3;
          break;
        }
        case 'guard': {
          enum24 = 4;
          break;
        }
        case 'hamster-curse': {
          enum24 = 5;
          break;
        }
        case 'love': {
          enum24 = 6;
          break;
        }
        case 'lovers-suicide': {
          enum24 = 7;
          break;
        }
        case 'fake-love': {
          enum24 = 8;
          break;
        }
        case 'unknown': {
          enum24 = 9;
          break;
        }
        default: {
          if ((v19_2) instanceof Error) {
            console.error(v19_2);
          }

          throw new TypeError(`"${val24}" is not one of the cases of action-type`);
        }
      }
      dataView(memory0).setInt8(base + 20, enum24, true);
      var variant26 = v19_3;
      if (variant26 === null || variant26=== undefined) {
        dataView(memory0).setInt8(base + 24, 0, true);
      } else {
        const e = variant26;
        dataView(memory0).setInt8(base + 24, 1, true);

        var encodeRes = _utf8AllocateAndEncode(e, realloc0, memory0);
        var ptr25= encodeRes.ptr;
        var len25 = encodeRes.len;

        dataView(memory0).setUint32(base + 32, len25, true);
        dataView(memory0).setUint32(base + 28, ptr25, true);
      }
      var variant28 = v19_4;
      if (variant28 === null || variant28=== undefined) {
        dataView(memory0).setInt8(base + 36, 0, true);
      } else {
        const e = variant28;
        dataView(memory0).setInt8(base + 36, 1, true);

        var encodeRes = _utf8AllocateAndEncode(e, realloc0, memory0);
        var ptr27= encodeRes.ptr;
        var len27 = encodeRes.len;

        dataView(memory0).setUint32(base + 44, len27, true);
        dataView(memory0).setUint32(base + 40, ptr27, true);
      }
      var variant30 = v19_5;
      if (variant30 === null || variant30=== undefined) {
        dataView(memory0).setInt8(base + 48, 0, true);
      } else {
        const e = variant30;
        dataView(memory0).setInt8(base + 48, 1, true);
        var variant29 = e;
        switch (variant29.tag) {
          case 'dead': {
            dataView(memory0).setInt8(base + 49, 0, true);
            break;
          }
          case 'guarded': {
            dataView(memory0).setInt8(base + 49, 1, true);
            break;
          }
          case 'partnered': {
            dataView(memory0).setInt8(base + 49, 2, true);
            break;
          }
          case 'wolf': {
            dataView(memory0).setInt8(base + 49, 3, true);
            break;
          }
          case 'non-wolf': {
            dataView(memory0).setInt8(base + 49, 4, true);
            break;
          }
          default: {
            throw new TypeError(`invalid variant tag value \`${JSON.stringify(variant29.tag)}\` (received \`${variant29}\`) specified for \`LogResult\``);
          }
        }
      }
    }
    dataView(memory0).setUint32(base + 16, len31, true);
    dataView(memory0).setUint32(base + 12, result31, true);
  }
  var vec38 = arg1;
  var len38 = vec38.length;
  var result38 = realloc0(0, 0, 4, len38 * 24);
  for (let i = 0; i < vec38.length; i++) {
    const e = vec38[i];
    const base = result38 + i * 24;var {actor: v33_0, actionType: v33_1, target: v33_2 } = e;

    var encodeRes = _utf8AllocateAndEncode(v33_0, realloc0, memory0);
    var ptr34= encodeRes.ptr;
    var len34 = encodeRes.len;

    dataView(memory0).setUint32(base + 4, len34, true);
    dataView(memory0).setUint32(base + 0, ptr34, true);
    var val35 = v33_1;
    let enum35;
    switch (val35) {
      case 'vote': {
        enum35 = 0;
        break;
      }
      case 'bite': {
        enum35 = 1;
        break;
      }
      case 'divine': {
        enum35 = 2;
        break;
      }
      case 'medium': {
        enum35 = 3;
        break;
      }
      case 'guard': {
        enum35 = 4;
        break;
      }
      case 'hamster-curse': {
        enum35 = 5;
        break;
      }
      case 'love': {
        enum35 = 6;
        break;
      }
      case 'lovers-suicide': {
        enum35 = 7;
        break;
      }
      case 'fake-love': {
        enum35 = 8;
        break;
      }
      case 'unknown': {
        enum35 = 9;
        break;
      }
      default: {
        if ((v33_1) instanceof Error) {
          console.error(v33_1);
        }

        throw new TypeError(`"${val35}" is not one of the cases of action-type`);
      }
    }
    dataView(memory0).setInt8(base + 8, enum35, true);
    var variant37 = v33_2;
    if (variant37 === null || variant37=== undefined) {
      dataView(memory0).setInt8(base + 12, 0, true);
    } else {
      const e = variant37;
      dataView(memory0).setInt8(base + 12, 1, true);

      var encodeRes = _utf8AllocateAndEncode(e, realloc0, memory0);
      var ptr36= encodeRes.ptr;
      var len36 = encodeRes.len;

      dataView(memory0).setUint32(base + 20, len36, true);
      dataView(memory0).setUint32(base + 16, ptr36, true);
    }
  }
  _debugLog('[iface="kuboon:jinro/engine", function="process-day"][Instruction::CallWasm] enter', {
    funcName: 'process-day',
    paramCount: 7,
    async: false,
    postReturn: true,
  });
  const hostProvided = false;

  const [task, _wasm_call_currentTaskID] = createNewCurrentTask({
    componentIdx: 0,
    isAsync: false,
    isManualAsync: false,
    entryFnName: 'engineProcessDay',
    getCallbackFn: () => null,
    callbackFnName: 'null',
    errHandling: 'throw-result-err',
    callingWasmExport: true,
  });

  const started = task.enterSync();
  task.setReturnMemoryIdx(0);
  task.setReturnMemory(memory0);
  let ret =   _withGlobalCurrentTaskMeta({
    taskID: task.id(),
    componentIdx: task.componentIdx(),
    fn: () => engineProcessDay(variant2_0, result11, len11, result32, len32, result38, len38),
  });

  let variant95;
  switch (dataView(memory0).getUint8(ret + 0, true)) {
    case 0: {
      var ptr39 = dataView(memory0).getUint32(ret + 4, true);
      var len39 = dataView(memory0).getUint32(ret + 8, true);
      var result39 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr39, len39));
      var len41 = dataView(memory0).getUint32(ret + 16, true);
      var base41 = dataView(memory0).getUint32(ret + 12, true);
      var result41 = [];
      for (let i = 0; i < len41; i++) {
        const base = base41 + i * 8;
        var ptr40 = dataView(memory0).getUint32(base + 0, true);
        var len40 = dataView(memory0).getUint32(base + 4, true);
        var result40 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr40, len40));
        result41.push(result40);
      }
      var len53 = dataView(memory0).getUint32(ret + 24, true);
      var base53 = dataView(memory0).getUint32(ret + 20, true);
      var result53 = [];
      for (let i = 0; i < len53; i++) {
        const base = base53 + i * 52;
        var ptr42 = dataView(memory0).getUint32(base + 0, true);
        var len42 = dataView(memory0).getUint32(base + 4, true);
        var result42 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr42, len42));
        let variant45;
        switch (dataView(memory0).getUint8(base + 8, true)) {
          case 0: {
            variant45= {
              tag: 'all',
            };
            break;
          }
          case 1: {
            variant45= {
              tag: 'afterall',
            };
            break;
          }
          case 2: {
            var len44 = dataView(memory0).getUint32(base + 16, true);
            var base44 = dataView(memory0).getUint32(base + 12, true);
            var result44 = [];
            for (let i = 0; i < len44; i++) {
              const base = base44 + i * 8;
              var ptr43 = dataView(memory0).getUint32(base + 0, true);
              var len43 = dataView(memory0).getUint32(base + 4, true);
              var result43 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr43, len43));
              result44.push(result43);
            }
            variant45= {
              tag: 'only',
              val: result44
            };
            break;
          }
          default: {
            throw new TypeError('invalid variant discriminant for Receivers');
          }
        }
        let enum46;
        switch (dataView(memory0).getUint8(base + 20, true)) {
          case 0: {
            enum46 = 'vote';
            break;
          }
          case 1: {
            enum46 = 'bite';
            break;
          }
          case 2: {
            enum46 = 'divine';
            break;
          }
          case 3: {
            enum46 = 'medium';
            break;
          }
          case 4: {
            enum46 = 'guard';
            break;
          }
          case 5: {
            enum46 = 'hamster-curse';
            break;
          }
          case 6: {
            enum46 = 'love';
            break;
          }
          case 7: {
            enum46 = 'lovers-suicide';
            break;
          }
          case 8: {
            enum46 = 'fake-love';
            break;
          }
          case 9: {
            enum46 = 'unknown';
            break;
          }
          default: {
            throw new TypeError('invalid discriminant specified for ActionType');
          }
        }
        let variant48;
        switch (dataView(memory0).getUint8(base + 24, true)) {
          case 0: {
            variant48 = undefined;
            break;
          }
          case 1: {
            var ptr47 = dataView(memory0).getUint32(base + 28, true);
            var len47 = dataView(memory0).getUint32(base + 32, true);
            var result47 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr47, len47));
            variant48 = result47;
            break;
          }
          default: {
            throw new TypeError('invalid variant discriminant for option');
          }
        }
        let variant50;
        switch (dataView(memory0).getUint8(base + 36, true)) {
          case 0: {
            variant50 = undefined;
            break;
          }
          case 1: {
            var ptr49 = dataView(memory0).getUint32(base + 40, true);
            var len49 = dataView(memory0).getUint32(base + 44, true);
            var result49 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr49, len49));
            variant50 = result49;
            break;
          }
          default: {
            throw new TypeError('invalid variant discriminant for option');
          }
        }
        let variant52;
        switch (dataView(memory0).getUint8(base + 48, true)) {
          case 0: {
            variant52 = undefined;
            break;
          }
          case 1: {
            let variant51;
            switch (dataView(memory0).getUint8(base + 49, true)) {
              case 0: {
                variant51= {
                  tag: 'dead',
                };
                break;
              }
              case 1: {
                variant51= {
                  tag: 'guarded',
                };
                break;
              }
              case 2: {
                variant51= {
                  tag: 'partnered',
                };
                break;
              }
              case 3: {
                variant51= {
                  tag: 'wolf',
                };
                break;
              }
              case 4: {
                variant51= {
                  tag: 'non-wolf',
                };
                break;
              }
              default: {
                throw new TypeError('invalid variant discriminant for LogResult');
              }
            }
            variant52 = variant51;
            break;
          }
          default: {
            throw new TypeError('invalid variant discriminant for option');
          }
        }
        result53.push({
          id: result42,
          receivers: variant45,
          actionType: enum46,
          actor: variant48,
          target: variant50,
          logResult: variant52,
        });
      }
      let variant54;
      switch (dataView(memory0).getUint8(ret + 28, true)) {
        case 0: {
          variant54= {
            tag: 'public',
          };
          break;
        }
        case 1: {
          variant54= {
            tag: 'private',
          };
          break;
        }
        default: {
          throw new TypeError('invalid variant discriminant for VoteRule');
        }
      }
      var len60 = dataView(memory0).getUint32(ret + 36, true);
      var base60 = dataView(memory0).getUint32(ret + 32, true);
      var result60 = [];
      for (let i = 0; i < len60; i++) {
        const base = base60 + i * 20;
        var ptr55 = dataView(memory0).getUint32(base + 0, true);
        var len55 = dataView(memory0).getUint32(base + 4, true);
        var result55 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr55, len55));
        let enum56;
        switch (dataView(memory0).getUint8(base + 8, true)) {
          case 0: {
            enum56 = 'villager';
            break;
          }
          case 1: {
            enum56 = 'seer';
            break;
          }
          case 2: {
            enum56 = 'bodyguard';
            break;
          }
          case 3: {
            enum56 = 'wolf';
            break;
          }
          case 4: {
            enum56 = 'madman';
            break;
          }
          case 5: {
            enum56 = 'lover';
            break;
          }
          case 6: {
            enum56 = 'bitch';
            break;
          }
          case 7: {
            enum56 = 'medium';
            break;
          }
          case 8: {
            enum56 = 'hamster';
            break;
          }
          default: {
            throw new TypeError('invalid discriminant specified for RoleType');
          }
        }
        var len59 = dataView(memory0).getUint32(base + 16, true);
        var base59 = dataView(memory0).getUint32(base + 12, true);
        var result59 = [];
        for (let i = 0; i < len59; i++) {
          const base = base59 + i * 16;
          var ptr57 = dataView(memory0).getUint32(base + 0, true);
          var len57 = dataView(memory0).getUint32(base + 4, true);
          var result57 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr57, len57));
          var ptr58 = dataView(memory0).getUint32(base + 8, true);
          var len58 = dataView(memory0).getUint32(base + 12, true);
          var result58 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr58, len58));
          result59.push([result57, result58]);
        }
        result60.push({
          id: result55,
          role: {
            roleType: enum56,
            opts: result59,
          },
        });
      }
      var len78 = dataView(memory0).getUint32(ret + 44, true);
      var base78 = dataView(memory0).getUint32(ret + 40, true);
      var result78 = [];
      for (let i = 0; i < len78; i++) {
        const base = base78 + i * 20;
        var len65 = dataView(memory0).getUint32(base + 8, true);
        var base65 = dataView(memory0).getUint32(base + 4, true);
        var result65 = [];
        for (let i = 0; i < len65; i++) {
          const base = base65 + i * 24;
          var ptr61 = dataView(memory0).getUint32(base + 0, true);
          var len61 = dataView(memory0).getUint32(base + 4, true);
          var result61 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr61, len61));
          let enum62;
          switch (dataView(memory0).getUint8(base + 8, true)) {
            case 0: {
              enum62 = 'vote';
              break;
            }
            case 1: {
              enum62 = 'bite';
              break;
            }
            case 2: {
              enum62 = 'divine';
              break;
            }
            case 3: {
              enum62 = 'medium';
              break;
            }
            case 4: {
              enum62 = 'guard';
              break;
            }
            case 5: {
              enum62 = 'hamster-curse';
              break;
            }
            case 6: {
              enum62 = 'love';
              break;
            }
            case 7: {
              enum62 = 'lovers-suicide';
              break;
            }
            case 8: {
              enum62 = 'fake-love';
              break;
            }
            case 9: {
              enum62 = 'unknown';
              break;
            }
            default: {
              throw new TypeError('invalid discriminant specified for ActionType');
            }
          }
          let variant64;
          switch (dataView(memory0).getUint8(base + 12, true)) {
            case 0: {
              variant64 = undefined;
              break;
            }
            case 1: {
              var ptr63 = dataView(memory0).getUint32(base + 16, true);
              var len63 = dataView(memory0).getUint32(base + 20, true);
              var result63 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr63, len63));
              variant64 = result63;
              break;
            }
            default: {
              throw new TypeError('invalid variant discriminant for option');
            }
          }
          result65.push({
            actor: result61,
            actionType: enum62,
            target: variant64,
          });
        }
        var len77 = dataView(memory0).getUint32(base + 16, true);
        var base77 = dataView(memory0).getUint32(base + 12, true);
        var result77 = [];
        for (let i = 0; i < len77; i++) {
          const base = base77 + i * 52;
          var ptr66 = dataView(memory0).getUint32(base + 0, true);
          var len66 = dataView(memory0).getUint32(base + 4, true);
          var result66 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr66, len66));
          let variant69;
          switch (dataView(memory0).getUint8(base + 8, true)) {
            case 0: {
              variant69= {
                tag: 'all',
              };
              break;
            }
            case 1: {
              variant69= {
                tag: 'afterall',
              };
              break;
            }
            case 2: {
              var len68 = dataView(memory0).getUint32(base + 16, true);
              var base68 = dataView(memory0).getUint32(base + 12, true);
              var result68 = [];
              for (let i = 0; i < len68; i++) {
                const base = base68 + i * 8;
                var ptr67 = dataView(memory0).getUint32(base + 0, true);
                var len67 = dataView(memory0).getUint32(base + 4, true);
                var result67 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr67, len67));
                result68.push(result67);
              }
              variant69= {
                tag: 'only',
                val: result68
              };
              break;
            }
            default: {
              throw new TypeError('invalid variant discriminant for Receivers');
            }
          }
          let enum70;
          switch (dataView(memory0).getUint8(base + 20, true)) {
            case 0: {
              enum70 = 'vote';
              break;
            }
            case 1: {
              enum70 = 'bite';
              break;
            }
            case 2: {
              enum70 = 'divine';
              break;
            }
            case 3: {
              enum70 = 'medium';
              break;
            }
            case 4: {
              enum70 = 'guard';
              break;
            }
            case 5: {
              enum70 = 'hamster-curse';
              break;
            }
            case 6: {
              enum70 = 'love';
              break;
            }
            case 7: {
              enum70 = 'lovers-suicide';
              break;
            }
            case 8: {
              enum70 = 'fake-love';
              break;
            }
            case 9: {
              enum70 = 'unknown';
              break;
            }
            default: {
              throw new TypeError('invalid discriminant specified for ActionType');
            }
          }
          let variant72;
          switch (dataView(memory0).getUint8(base + 24, true)) {
            case 0: {
              variant72 = undefined;
              break;
            }
            case 1: {
              var ptr71 = dataView(memory0).getUint32(base + 28, true);
              var len71 = dataView(memory0).getUint32(base + 32, true);
              var result71 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr71, len71));
              variant72 = result71;
              break;
            }
            default: {
              throw new TypeError('invalid variant discriminant for option');
            }
          }
          let variant74;
          switch (dataView(memory0).getUint8(base + 36, true)) {
            case 0: {
              variant74 = undefined;
              break;
            }
            case 1: {
              var ptr73 = dataView(memory0).getUint32(base + 40, true);
              var len73 = dataView(memory0).getUint32(base + 44, true);
              var result73 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr73, len73));
              variant74 = result73;
              break;
            }
            default: {
              throw new TypeError('invalid variant discriminant for option');
            }
          }
          let variant76;
          switch (dataView(memory0).getUint8(base + 48, true)) {
            case 0: {
              variant76 = undefined;
              break;
            }
            case 1: {
              let variant75;
              switch (dataView(memory0).getUint8(base + 49, true)) {
                case 0: {
                  variant75= {
                    tag: 'dead',
                  };
                  break;
                }
                case 1: {
                  variant75= {
                    tag: 'guarded',
                  };
                  break;
                }
                case 2: {
                  variant75= {
                    tag: 'partnered',
                  };
                  break;
                }
                case 3: {
                  variant75= {
                    tag: 'wolf',
                  };
                  break;
                }
                case 4: {
                  variant75= {
                    tag: 'non-wolf',
                  };
                  break;
                }
                default: {
                  throw new TypeError('invalid variant discriminant for LogResult');
                }
              }
              variant76 = variant75;
              break;
            }
            default: {
              throw new TypeError('invalid variant discriminant for option');
            }
          }
          result77.push({
            id: result66,
            receivers: variant69,
            actionType: enum70,
            actor: variant72,
            target: variant74,
            logResult: variant76,
          });
        }
        result78.push({
          dayNumber: dataView(memory0).getInt32(base + 0, true),
          actions: result65,
          logs: result77,
        });
      }
      let variant80;
      switch (dataView(memory0).getUint8(ret + 52, true)) {
        case 0: {
          variant80 = undefined;
          break;
        }
        case 1: {
          let enum79;
          switch (dataView(memory0).getUint8(ret + 53, true)) {
            case 0: {
              enum79 = 'villagers';
              break;
            }
            case 1: {
              enum79 = 'wolves';
              break;
            }
            case 2: {
              enum79 = 'hamsters';
              break;
            }
            case 3: {
              enum79 = 'lovers';
              break;
            }
            default: {
              throw new TypeError('invalid discriminant specified for Team');
            }
          }
          variant80 = enum79;
          break;
        }
        default: {
          throw new TypeError('invalid variant discriminant for option');
        }
      }
      var len92 = dataView(memory0).getUint32(ret + 60, true);
      var base92 = dataView(memory0).getUint32(ret + 56, true);
      var result92 = [];
      for (let i = 0; i < len92; i++) {
        const base = base92 + i * 32;
        var ptr81 = dataView(memory0).getUint32(base + 0, true);
        var len81 = dataView(memory0).getUint32(base + 4, true);
        var result81 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr81, len81));
        let enum82;
        switch (dataView(memory0).getUint8(base + 8, true)) {
          case 0: {
            enum82 = 'villager';
            break;
          }
          case 1: {
            enum82 = 'seer';
            break;
          }
          case 2: {
            enum82 = 'bodyguard';
            break;
          }
          case 3: {
            enum82 = 'wolf';
            break;
          }
          case 4: {
            enum82 = 'madman';
            break;
          }
          case 5: {
            enum82 = 'lover';
            break;
          }
          case 6: {
            enum82 = 'bitch';
            break;
          }
          case 7: {
            enum82 = 'medium';
            break;
          }
          case 8: {
            enum82 = 'hamster';
            break;
          }
          default: {
            throw new TypeError('invalid discriminant specified for RoleType');
          }
        }
        let enum83;
        switch (dataView(memory0).getUint8(base + 9, true)) {
          case 0: {
            enum83 = 'villagers';
            break;
          }
          case 1: {
            enum83 = 'wolves';
            break;
          }
          case 2: {
            enum83 = 'hamsters';
            break;
          }
          case 3: {
            enum83 = 'lovers';
            break;
          }
          default: {
            throw new TypeError('invalid discriminant specified for Team');
          }
        }
        var len87 = dataView(memory0).getUint32(base + 16, true);
        var base87 = dataView(memory0).getUint32(base + 12, true);
        var result87 = [];
        for (let i = 0; i < len87; i++) {
          const base = base87 + i * 12;
          let enum84;
          switch (dataView(memory0).getUint8(base + 0, true)) {
            case 0: {
              enum84 = 'vote';
              break;
            }
            case 1: {
              enum84 = 'bite';
              break;
            }
            case 2: {
              enum84 = 'divine';
              break;
            }
            case 3: {
              enum84 = 'medium';
              break;
            }
            case 4: {
              enum84 = 'guard';
              break;
            }
            case 5: {
              enum84 = 'hamster-curse';
              break;
            }
            case 6: {
              enum84 = 'love';
              break;
            }
            case 7: {
              enum84 = 'lovers-suicide';
              break;
            }
            case 8: {
              enum84 = 'fake-love';
              break;
            }
            case 9: {
              enum84 = 'unknown';
              break;
            }
            default: {
              throw new TypeError('invalid discriminant specified for ActionType');
            }
          }
          var len86 = dataView(memory0).getUint32(base + 8, true);
          var base86 = dataView(memory0).getUint32(base + 4, true);
          var result86 = [];
          for (let i = 0; i < len86; i++) {
            const base = base86 + i * 8;
            var ptr85 = dataView(memory0).getUint32(base + 0, true);
            var len85 = dataView(memory0).getUint32(base + 4, true);
            var result85 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr85, len85));
            result86.push(result85);
          }
          result87.push({
            actionType: enum84,
            targets: result86,
          });
        }
        let variant89;
        switch (dataView(memory0).getUint8(base + 20, true)) {
          case 0: {
            variant89 = undefined;
            break;
          }
          case 1: {
            let enum88;
            switch (dataView(memory0).getUint8(base + 21, true)) {
              case 0: {
                enum88 = 'executed';
                break;
              }
              case 1: {
                enum88 = 'found-dead';
                break;
              }
              default: {
                throw new TypeError('invalid discriminant specified for CauseOfDeath');
              }
            }
            variant89 = enum88;
            break;
          }
          default: {
            throw new TypeError('invalid variant discriminant for option');
          }
        }
        var len91 = dataView(memory0).getUint32(base + 28, true);
        var base91 = dataView(memory0).getUint32(base + 24, true);
        var result91 = [];
        for (let i = 0; i < len91; i++) {
          const base = base91 + i * 8;
          var ptr90 = dataView(memory0).getUint32(base + 0, true);
          var len90 = dataView(memory0).getUint32(base + 4, true);
          var result90 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr90, len90));
          result91.push(result90);
        }
        result92.push({
          id: result81,
          roleType: enum82,
          team: enum83,
          availableActions: result87,
          causeOfDeath: variant89,
          logIds: result91,
        });
      }
      variant95= {
        tag: 'ok',
        val: [{
          voted: result39,
          deads: result41,
          logs: result53,
        }, {
          rule: {
            vote: variant54,
          },
          creatures: result60,
          days: result78,
        }, {
          dayNumber: dataView(memory0).getInt32(ret + 48, true),
          winner: variant80,
          creatureStatuses: result92,
        }]
      };
      break;
    }
    case 1: {
      let variant94;
      switch (dataView(memory0).getUint8(ret + 4, true)) {
        case 0: {
          var ptr93 = dataView(memory0).getUint32(ret + 8, true);
          var len93 = dataView(memory0).getUint32(ret + 12, true);
          var result93 = TEXT_DECODER_UTF8.decode(new Uint8Array(memory0.buffer, ptr93, len93));
          variant94= {
            tag: 'data-error',
            val: result93
          };
          break;
        }
        default: {
          throw new TypeError('invalid variant discriminant for DataError');
        }
      }
      variant95= {
        tag: 'err',
        val: variant94
      };
      break;
    }
    default: {
      throw new TypeError('invalid variant discriminant for expected');
    }
  }
  _debugLog('[iface="kuboon:jinro/engine", function="process-day"][Instruction::Return]', {
    funcName: 'process-day',
    paramCount: 1,
    async: false,
    postReturn: true
  });
  const retCopy = variant95;
  task.resolve([retCopy.val]);

  let cstate = getOrCreateAsyncState(0);
  cstate.mayLeave = false;
  postReturn1(ret);
  cstate.mayLeave = true;
  task.exit();



  if (typeof retCopy === 'object' && retCopy.tag === 'err') {
    throw new ComponentError(retCopy.val);
  }
  return retCopy.val;

}

const $init = (() => {
  let gen = (function* _initGenerator () {
    const module0 = fetchCompile(new URL('./jinro_component.core.wasm', import.meta.url));
    ({ exports: exports0 } = yield instantiateCore(yield module0));
    memory0 = exports0.memory;
    realloc0 = exports0.cabi_realloc;

    try {
      realloc0Async = WebAssembly.promising(exports0.cabi_realloc);
    } catch(err) {
      realloc0Async = exports0.cabi_realloc;
    }

    postReturn0 = exports0['cabi_post_kuboon:jinro/engine#create-village'];

    try {
      postReturn0Async = WebAssembly.promising(exports0['cabi_post_kuboon:jinro/engine#create-village']);
    } catch(err) {
      postReturn0Async = exports0['cabi_post_kuboon:jinro/engine#create-village'];
    }

    postReturn1 = exports0['cabi_post_kuboon:jinro/engine#process-day'];

    try {
      postReturn1Async = WebAssembly.promising(exports0['cabi_post_kuboon:jinro/engine#process-day']);
    } catch(err) {
      postReturn1Async = exports0['cabi_post_kuboon:jinro/engine#process-day'];
    }

    engineCreateVillage = exports0['kuboon:jinro/engine#create-village'];
    engineProcessDay = exports0['kuboon:jinro/engine#process-day'];
  })();
  let promise, resolve, reject;
  function runNext (value) {
    try {
      let done;
      do {
        ({ value, done } = gen.next(value));
      } while (!(value instanceof Promise) && !done);
      if (done) {
        if (resolve) resolve(value);
        else return value;
      }
      if (!promise) promise = new Promise((_resolve, _reject) => (resolve = _resolve, reject = _reject));
      value.then(runNext, reject);
    }
    catch (e) {
      if (reject) reject(e);
      else throw e;
    }
  }
  const maybeSyncReturn = runNext(null);
  return promise || maybeSyncReturn;
})();

await $init;
const engine = {
  createVillage: createVillage,
  processDay: processDay,

};

export { engine, engine as 'kuboon:jinro/engine',  }