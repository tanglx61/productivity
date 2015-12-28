function showAlert(msg)
	hs.alert.show(msg)
end

function showNotification(title, msg)
	hs.notify.new({title=title, informativeText=msg}):send()
end


hs.hotkey.bind({"cmd", "alt", "ctrl"}, "Left", function()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	local screen = win:screen()
	local max = screen:frame()

	f.x = max.x
	f.y = max.y
	f.w = max.w / 2
	f.h = max.h
	win:setFrame(f)

	showAlert('←')
end)

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "Right", function()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	local screen = win:screen()
	local max = screen:frame()

	f.x = max.x + (max.w / 2)
	f.y = max.y
	f.w = max.w / 2
	f.h = max.h
	win:setFrame(f)
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
function stackTerminals()
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

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "C", stackTerminals)

-- Automatic script reloading with pathwatcher
function reloadConfig(files)
    doReload = false
    for _,file in pairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
        end
    end
    if doReload then
        hs.reload()
    end
end
hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()
hs.alert.show("Config loaded") 
