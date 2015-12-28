local logLevel = 'debug' -- generally want 'debug' or 'info'
local log = hs.logger.new('tanglx61', logLevel)

function showAlert(msg)
	hs.alert.show(msg)
end

function showNotification(title, msg)
	hs.notify.new({title=title, informativeText=msg}):send()
end


hs.hotkey.bind({"cmd", "alt", "ctrl"}, "Left", function()
	local win = hs.window.focusedWindow()
	local rect = hs.geometry.rect(0, 0, 0.5, 1.0)
	win:moveToUnit(rect)

	showAlert('←')
end)

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "Right", function()
	local win = hs.window.focusedWindow()
	local rect = hs.geometry.rect(0.5, 0, 0.5, 1.0)
	win:moveToUnit(rect)

	showAlert('→')
end)

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "F", function()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	local screen = win:screen()
	local max = screen:frame()

	f.x = max.x
	f.y = max.y
	f.w = max.w 
	f.h = max.h
	win:setFrame(f)
	showAlert('↔')
end)


-- stack terminals to the right 1/3th of the screen
function stackTerminalWindows()
	hs.application.launchOrFocus('Terminal')
	local terminal = hs.application.get('Terminal')
	local terminalWindows = terminal:allWindows()

	local screenFrame = hs.window.focusedWindow():screen():frame()
	local terminalWindowWidth = screenFrame.w / 3
	local terminalWindowHeight = screenFrame.h / #terminalWindows
	local terminalWindowX = screenFrame.x + screenFrame.w * 2 / 3

	local i = 0

	hs.fnutils.each(terminalWindows, function(terminalWindow)
		terminalWindow:focus()
		local f = terminalWindow:frame()
		f.x = terminalWindowX
		f.w = terminalWindowWidth
		f.h = terminalWindowHeight
		f.y = i * terminalWindowHeight
		i = i+1
		terminalWindow:setFrame(f)
		end)
end

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "C", stackTerminalWindows)


-- Event-handling
--
-- This will become a lot easier once `hs.window.filter`
-- (http://www.hammerspoon.org/docs/hs.window.filter.html) moves out of
-- "experimental" status, but until then, using a manual approach as
-- demonstrated at: https://gist.github.com/tmandry/a5b1ab6d6ea012c1e8c5

local globalWatcher = nil
local watchers = {}
local events = hs.uielement.watcher

local APPS_TO_WATCH = {
	Terminal = {events.windowCreated, events.windowMinimized, events.windowUnminimized}
}

function handleTerminalEvents(app, event)
	if event == events.windowCreated then
		showAlert('terminal new window')
	elseif event == events.windowMinimized then
		showAlert('terminal minimized')
	elseif event == events.windowUnminimized then
		showAlert('terminal unminimized')
	elseif event == events.elementDestroyed then
		showAlert('terminal closed window')
	end

end

function handleGlobalEvent(name, eventType, app)
  if eventType == hs.application.watcher.launched then
    log.df('[event] launched %s', app:bundleID())
    --watchApp(app)
  elseif eventType == hs.application.watcher.terminated then
    -- Only the PID is set for terminated apps, so can't log bundleID.
    local pid = app:pid()
    log.df('[event] terminated PID %d', pid)
    unwatchApp(pid)
  end
end

function handleAppEvent(element, event, watcher, info)
	local appName = info.appName
	if event == events.windowCreated then
		watchWindow(element, appName)
		log.d('[event] created new window for app ' .. info.appName)
	end

	if appName == 'Terminal' then
		handleTerminalEvents(elment, event)
	end
end

function handleWindowEvent(window, event, watcher, info)
	local appName = info['appName']

	if appName == 'Terminal' then
		handleTerminalEvents(window, event)
	end


	if event == events.elementDestroyed then
		log.df('[event] window %s destroyed, appName = ' .. appName, info.id)
		watcher:stop()
		watchers[info.pid].windows[info.id] = nil
	else
    	log.wf('unexpected window event %d received', event)
	end
end



function watchApp(app, appName, events)
	log.d('watching app ' .. appName)
  local pid = app:pid()
  if watchers[pid] then
    log.wf('attempted watch for already-watched PID %d', pid)
    return
  end


  -- Watch for new windows.
  local watcher = app:newWatcher(handleAppEvent, {appName=appName})
  watchers[pid] = {
    watcher = watcher,
    windows = {},
  }
  watcher:start(events)

  -- Watch already-existing windows.
  for _, window in pairs(app:allWindows()) do
    watchWindow(window, appName)
  end
end

function unwatchApp(pid)
  local appWatcher = watchers[pid]
  if not appWatcher then
    log.wf('attempted unwatch for unknown PID %d', pid)
    return
  end

  appWatcher.watcher:stop()
  for _, watcher in pairs(appWatcher.windows) do
    watcher:stop()
  end
  watchers[pid] = nil
end

function watchWindow(window, appName)
	log.d('watching a new window for app ' .. appName)
  local application = window:application()
  local pid = application:pid()
  local windows = watchers[pid].windows
  if window:isStandard() then
    -- Do initial layout-handling.
    -- local bundleID = application:bundleID()
    -- if layoutConfig[bundleID] then
    --   layoutConfig[bundleID](window)
    -- end

    -- Watch for window-closed events.
    local id = window:id()
    if not windows[id] then
      local watcher = window:newWatcher(handleWindowEvent, {
        id = id,
        pid = pid,
        appName = appName
      })
      windows[id] = watcher
      watcher:start({events.elementDestroyed})
    end
  end
end

function initEventHandling()
  -- Watch for application-level events.
  globalWatcher = hs.application.watcher.new(handleGlobalEvent)
  globalWatcher:start()

  -- Watch already-running applications.
  for appName, events in pairs(APPS_TO_WATCH) do
  	local app = hs.application.get(appName)
  	if app then
  		local events = APPS_TO_WATCH[appName]
  		watchApp(app, appName, events)
  	else 
  		log:e('app ' .. appName .. ' not found')
  	end
  end
  

end

function tearDownEventHandling()
  globalWatcher:stop()
  globalWatcher = nil

  for pid, _ in pairs(watchers) do
    unwatchApp(pid)
  end
end

initEventHandling()


-- Automatic script reloading with pathwatcher
function reloadConfig(files)
    for _,file in pairs(files) do
        if file:sub(-4) == ".lua" then
            tearDownEventHandling()
            hs.reload()
        end
    end
end
hs.pathwatcher.new(os.getenv("HOME") .. "/github/productivity/hammerspoon/", reloadConfig):start()
hs.alert.show("Config loaded") 
