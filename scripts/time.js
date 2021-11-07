exports.centerTime = (time) => {
  const now = parseInt(time || new Date().getTime() / 1000);

  const delta1s = 1;
  const delta1m = 1 * 60;
  const delta1h = 1 * 60 * 60;
  const delta1d = 24 * 60 * 60;

  const delta10s = 10 * delta1s;
  const delta10m = 10 * delta1m;
  const delta10h = 10 * delta1h;
  const delta10d = 10 * delta1d;

  const delta20s = 20 * delta1s;
  const delta20m = 20 * delta1m;
  const delta20h = 20 * delta1h;
  const delta20d = 20 * delta1d;

  const delta30s = 30 * delta1s;
  const delta30m = 30 * delta1m;
  const delta30h = 30 * delta1h;
  const delta30d = 30 * delta1d;

  const delta40s = 40 * delta1s;
  const delta40m = 40 * delta1m;
  const delta40h = 40 * delta1h;
  const delta40d = 40 * delta1d;

  const delta50s = 50 * delta1s;
  const delta50m = 50 * delta1m;
  const delta50h = 50 * delta1h;
  const delta50d = 50 * delta1d;

  const future1s = now + 1 * delta1s;
  const future1m = now + 1 * delta1m;
  const future1h = now + 1 * delta1h;
  const future1d = now + 1 * delta1d;

  const future10s = now + 10 * delta1s;
  const future10m = now + 10 * delta1m;
  const future10h = now + 10 * delta1h;
  const future10d = now + 10 * delta1d;

  const future20s = now + 20 * delta1s;
  const future20m = now + 20 * delta1m;
  const future20h = now + 20 * delta1h;
  const future20d = now + 20 * delta1d;

  const future30s = now + 30 * delta1s;
  const future30m = now + 30 * delta1m;
  const future30h = now + 30 * delta1h;
  const future30d = now + 30 * delta1d;

  const future40s = now + 40 * delta1s;
  const future40m = now + 40 * delta1m;
  const future40h = now + 40 * delta1h;
  const future40d = now + 40 * delta1d;

  const future50s = now + 50 * delta1s;
  const future50m = now + 50 * delta1m;
  const future50h = now + 50 * delta1h;
  const future50d = now + 50 * delta1d;

  return {
    now: now,

    delta1s: delta1s,
    delta1m: delta1m,
    delta1h: delta1h,
    delta1d: delta1d,

    delta10s: delta10s,
    delta10m: delta10m,
    delta10h: delta10h,
    delta10d: delta10d,

    delta20s: delta20s,
    delta20m: delta20m,
    delta20h: delta20h,
    delta20d: delta20d,

    delta30s: delta30s,
    delta30m: delta30m,
    delta30h: delta30h,
    delta30d: delta30d,

    delta40s: delta40s,
    delta40m: delta40m,
    delta40h: delta40h,
    delta40d: delta40d,

    delta50s: delta50s,
    delta50m: delta50m,
    delta50h: delta50h,
    delta50d: delta50d,

    future1s: future1s,
    future1m: future1m,
    future1h: future1h,
    future1d: future1d,

    future10s: future10s,
    future10m: future10m,
    future10h: future10h,
    future10d: future10d,

    future20s: future20s,
    future20m: future20m,
    future20h: future20h,
    future20d: future20d,

    future30s: future30s,
    future30m: future30m,
    future30h: future30h,
    future30d: future30d,

    future40s: future40s,
    future40m: future40m,
    future40h: future40h,
    future40d: future40d,

    future50s: future50s,
    future50m: future50m,
    future50h: future50h,
    future50d: future50d,
  };
};
