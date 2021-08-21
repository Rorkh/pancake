local sleep, get_time
local math_floor = math.floor

if not jit then -- not LuaJIT?
   return require "timer.c"
elseif jit.os == "Windows" then
   local ffi = require "ffi"
   ffi.cdef [[
      void __stdcall Sleep(unsigned dwMilliseconds);
      unsigned __stdcall GetTickCount(void);
   ]]
   local lib = ffi.load "KERNEL32"
   sleep = lib.Sleep
   get_time = lib.GetTickCount
else
   local ffi = require("ffi")
   ffi.cdef [[
      typedef long time_t;
      typedef int clockid_t;

      typedef struct timespec {
         time_t   tv_sec;        /* seconds */
         long     tv_nsec;       /* nanoseconds */
      } nanotime;
      int clock_gettime(clockid_t clk_id, struct timespec *tp);
      int clock_nanosleep(clockid_t clock_id, int flags,
         const struct timespec *rqtp, struct timespec *rmtp);
   ]]
   local pnano = assert(ffi.new("nanotime[?]", 1))
   function get_time()
      -- CLOCK_MONOTONIC -> 1
      ffi.C.clock_gettime(1, pnano)
      return tonumber(pnano[0].tv_sec * 1000
         + math_floor(tonumber(pnano[0].tv_nsec/1000000)))
   end
   function sleep(time)
      pnano[0].tv_sec = math_floor(time / 1000)
      pnano[0].tv_nsec = (time % 1000) * 1000000
      ffi.C.clock_nanosleep(1, 0, pnano, nil)
   end
end

local heap = {}

local function insert_timer(t)
   local index = #heap + 1
   t.index = index
   heap[index] = t
   while index > 1 do
      local parent = math_floor(index/2)
      if heap[parent].emittime <= t.emittime then
         break
      end
      heap[index], heap[parent] = heap[parent], heap[index]
      heap[index].index = index
      heap[parent].index = parent
      index = parent
   end
   return t
end

local function cancel_timer(t)
   if heap[t.index] ~= t then return end
   local index = t.index
   local heap_size = #heap
   if index == heap_size then
      heap[heap_size] = nil
      return
   end
   heap[index] = heap[heap_size]
   heap[index].index = index
   heap[heap_size] = nil
   while true do
      local left, right = math_floor(index*2), math_floor(index*2)+1
      local newindex = right
      if not heap[left] then break end
      if heap[index].emittime >= heap[left].emittime then
         if not heap[right] or heap[left].emittime < heap[right].emittime then
            newindex = left
         end
      elseif not heap[right] or heap[index].emittime <= heap[right].emittime then
         break
      end
      heap[index], heap[newindex] = heap[newindex], heap[index]
      heap[index].index = index
      heap[newindex].index = newindex
      index = newindex
   end
end

local function set_timer(elapsed, cb)
   local t = {}
   t.starttime = get_time()
   t.emittime  = t.starttime + elapsed
   t.cb        = cb
   return insert_timer(t)
end

local function checktimers(time)
   local time = time or get_time()
   local t = heap[1]
   while t and time >= t.emittime do
      local cb = t.cb
      cancel_timer(t)
      if cb then
         local nexttime = cb(time - t.starttime)
         if nexttime == true then
            nexttime = t.elapsed
         end
         if nexttime then
            t.starttime = time
            t.emittime = time + nexttime
            insert_timer(t)
         end
      end
      t = heap[1]
   end
end

local function waittimers()
   while heap[1] do
      local nexttime = heap[1] and heap[1].emittime
      local time = get_time()
      if nexttime > time then
         sleep(nexttime - time)
      end
      checktimers(get_time())
   end
end

--local cb = function() end
--for i = 1, 1000000 do
   --set_timer(math.random(1, 1000)*math.random(1, 1000), cb)
--end

-- waittimers()

return {
   set_timer    = set_timer,
   cancal_timer = cancal_timer,
   checktimers  = checktimers,
   waittimers   = waittimers
}