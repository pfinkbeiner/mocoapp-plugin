local M = {}

local user_input = {
  customer = "",
  project = "",
  task = "",
}

local ok, dressing = pcall(require, "dressing")
if ok then
  dressing.setup {
    input = {
      relative = 'editor',
      win_options = {
        winblend = 0
      }
    }
  }
end

local ok, notify = pcall(require, "notify")
if ok then
  vim.notify = notify
else
  print("Notify plugin not found. Falling back to default notify.")
  vim.notify = function(msg, log_level, opts)
    print(msg)
  end
end

local function api_request(endpoint, method, data, callback)
  local mocoapp_api_token = vim.g.mocoapp_api_token or nil
  if mocoapp_api_token == nil then
    vim.notify("Mocoapp token not set", "error")
    return
  end

  local mocoapp_api_domain = vim.g.mocoapp_api_domain or nil
  if mocoapp_api_domain == nil then
    vim.notify("Mocoapp domain not set. https://{domain}.mocoapp.com", "error")
    return
  end

  local cmd = "curl -s -X " .. method .. " 'https://".. mocoapp_api_domain ..".mocoapp.com/api/v1/" .. endpoint .. "' -H 'Content-Type: application/json' -H 'Authorization: Token token=" .. mocoapp_api_token .. "'"

  if method == "POST" or method == "PUT" then
    cmd = cmd .. " -d '" .. data .. "'"
  end

  local out = {}
  local jobid = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      if data then
        table.insert(out, table.concat(data, ""))
      end
    end,
    on_exit = function(_, exit_code, _)
      if exit_code == 0 then
        local output = table.concat(out, "")
        local json_data = vim.fn.json_decode(output)
        callback(json_data)
      else
        print("Failed to execute the command.")
      end
    end
  })

  if jobid <= 0 then
    print("Failed to start job")
  end
end

function is_valid_date(dateStr)
    -- Check the pattern "YYYY-MM-DD"
    local match = string.match(dateStr, "^(%d%d%d%d)-(%d%d)-(%d%d)$")
    if not match then return false end

    -- Extract year, month, and day
    local year, month, day = string.match(dateStr, "^(%d%d%d%d)-(%d%d)-(%d%d)$")

    -- Convert to numbers
    year, month, day = tonumber(year), tonumber(month), tonumber(day)

    -- Basic validation
    if month < 1 or month > 12 then return false end
    if day < 1 or day > 31 then return false end

    -- Check days in February
    if month == 2 then
        -- Check leap year
        local isLeapYear = (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0))
        if isLeapYear then
            if day > 29 then return false end
        else
            if day > 28 then return false end
        end
    elseif month == 4 or month == 6 or month == 9 or month == 11 then
        if day > 30 then return false end
    end

    return true
end

function seconds_to_time_format(seconds)
  local total_minutes = math.floor(seconds / 60)
  local hours = math.floor(total_minutes / 60)
  local remaining_minutes = total_minutes % 60

  return hours, remaining_minutes
end

function convert_timestr_to_hours_and_minutes(timeStr)
   -- Replace comma with period for uniformity
    timeStr = timeStr:gsub(",", ".")

    -- Convert string to number
    local decimalHours = tonumber(timeStr)
    if not decimalHours then
        vim.notify("Invalid time input, please try again.", "error")
        return nil, nil
    end

    -- Extract hours and minutes
    local hours = math.floor(decimalHours)
    local decimalPart = decimalHours - hours
    local minutes = math.floor(decimalPart * 60 + 0.5)  -- Rounded to the nearest minute

    return hours, minutes
end


M.fetch_projects = function()
  print("Fetching projects...")
  api_request("projects", "GET", nil, function(response)
    M.render_projects(response)
  end)
end

M.render_projects = function(projects)
  local items = {}
  for _, project in pairs(projects) do
    local customer_name = project.customer.name
    for _, task in pairs(project.tasks) do
      local display_str = string.format("%s > %s > %s", customer_name, project.name, task.name)
      table.insert(items, { display_str, project.id, task.id })
    end
  end

   vim.ui.select(items, {
     prompt = 'Select a project task: ',
     format_item = function(item)
       return item[1]
     end
     }, function(choice)
       if not choice then return end
       local project_id = choice[2]
       local task_id = choice[3]

       user_input.customer = choice[1]:match("^(.+) > .+ > .+$")
       user_input.project = choice[1]:match("^.+ > (.+) > .+$")
       user_input.task = choice[1]:match("^.+ > .+ > (.+)$")

       M.select_date(project_id, task_id)
     end
   )
end

M.select_date = function(project_id, task_id)
  local today = os.date("%Y-%m-%d")
  vim.ui.input({ prompt= "Enter date (YYYY-MM-DD): ", default = today}, function(input)
    if not is_valid_date(input) then
      print("Invalid date format. Please try again.")
      M.select_date(project_id, task_id)
      return
    end
    M.enter_time(project_id, task_id, input)
  end)
end

M.enter_time = function(project_id, task_id, date)
  vim.ui.input({ prompt= "Enter time like 4.25 (= 4h 15min):"}, function(input)
    local hours, minutes = convert_timestr_to_hours_and_minutes(input)
    local total_seconds = hours * 3600 + minutes * 60
    M.enter_description(project_id, task_id, date, total_seconds)
  end)
end

M.enter_description = function(project_id, task_id, date, time)
  vim.ui.input({ prompt= "Task description:"}, function(description)
    local escaped_description = string.gsub(description, "#", "\\#")
    M.save(project_id, task_id, date, time, escaped_description)
  end)
end

M.save = function (project_id, task_id, date, time, description)
  local data = vim.fn.json_encode({
    date = date,
    seconds = time,
    description = description,
    project_id = project_id,
    task_id = task_id
  })

  api_request("activities", "POST", data, function(response)
    local hours, minutes = seconds_to_time_format(time)

    local message = string.format(
      "%dh%dmin added to %s > %s > %s",
      hours,
      minutes,
      user_input.customer,
      user_input.project,
      user_input.task
    )
    vim.notify(message, "success")

    print(vim.inspect(response))
  end)
end

M.setup = function()
  vim.cmd[[command! Moco lua require'mocoapp-plugin'.fetch_projects()]]
end

return M
