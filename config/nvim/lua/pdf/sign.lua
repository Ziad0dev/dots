-- pdf.sign — cryptographic signing (dots-pdfsign): certificate setup, picking
-- where the signature goes, signing, verifying.
local core = require("pdf.core")

local M = {}

local function state_dir()
  return (vim.env.XDG_DATA_HOME or (vim.env.HOME .. "/.local/share")) .. "/dots/pdfsign"
end

local function conf_dir()
  return (vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")) .. "/dots"
end

local function present(path)
  return vim.uv.fs_stat(path) ~= nil
end

function M.has_cert()
  return present(state_dir() .. "/signing.p12")
end

function M.has_image()
  return present(state_dir() .. "/signature.png")
end

-- --- certificate & image -------------------------------------------------

--- Create the local self-signed certificate, then continue with `cb`.
function M.init(cb)
  local email = vim.trim(vim.fn.system({ "git", "config", "user.email" }))
  if vim.v.shell_error ~= 0 or email == "" then
    email = (vim.env.USER or "me") .. "@localhost"
  end
  core.ask({
    { key = "cn", prompt = "Name on the certificate: ", default = vim.env.USER },
    { key = "mail", prompt = "Email: ", default = email },
  }, function(v)
    core.run("sign", { "init", v.cn, v.mail }, {}, function(res)
      if res.code ~= 0 then
        return core.notify(vim.trim(res.stderr), vim.log.levels.ERROR)
      end
      core.notify("signing certificate created for " .. v.cn)
      if cb then
        cb()
      end
    end)
  end)
end

--- Use a real certificate. The passphrase is typed in a terminal split.
function M.import()
  core.input("Certificate (.p12/.pfx): ", "", "file", function(path)
    if not present(vim.fn.expand(path)) then
      return core.notify("no such file: " .. path, vim.log.levels.ERROR)
    end
    vim.cmd("botright split")
    vim.cmd("terminal dots-pdfsign import " .. vim.fn.shellescape(vim.fn.expand(path)))
    vim.cmd("startinsert")
  end)
end

--- Set (or clear) the handwritten-signature image used in visible signatures.
function M.image()
  core.input("Signature image (png/jpg, empty = remove): ", "", "file", function(path)
    local arg = path == "" and "-" or vim.fn.expand(path)
    core.run("sign", { "image", arg }, {}, function(res)
      if res.code ~= 0 then
        return core.notify(vim.trim(res.stderr), vim.log.levels.ERROR)
      end
      core.notify(vim.trim(res.stdout))
    end)
  end)
end

function M.status()
  core.show("sign", { "status" }, "signing identity")
end

function M.verify(pdf)
  core.show("sign", { "verify", pdf }, "signatures: " .. vim.fn.fnamemodify(pdf, ":t"))
end

-- --- signing -------------------------------------------------------------

local WHERE = {
  { label = "Next to text (e.g. “Signature:”)", kind = "at" },
  { label = "Existing signature field in the document", kind = "field" },
  { label = "Bottom right of the last page", kind = "where", value = "bottom-right" },
  { label = "Bottom left of the last page", kind = "where", value = "bottom-left" },
  { label = "Bottom centre of the last page", kind = "where", value = "bottom-center" },
  { label = "Top right of the last page", kind = "where", value = "top-right" },
  { label = "Exact box (page and points)", kind = "box" },
  { label = "Invisible", kind = "none" },
}

local function labels()
  return vim.tbl_map(function(w)
    return w.label
  end, WHERE)
end

--- Work out the placement flags, then call cb(flags).
local function placement(pdf, anchor, cb)
  core.select(labels(), { prompt = "Where should the signature go?" }, function(_, idx)
    local w = WHERE[idx]
    if w.kind == "none" then
      cb({})
    elseif w.kind == "where" then
      cb({ "--where", w.value })
    elseif w.kind == "at" then
      core.input("Place after text: ", anchor or "Signature", nil, function(t)
        cb(t ~= "" and { "--at", t } or nil)
      end)
    elseif w.kind == "box" then
      core.ask({
        { key = "page", prompt = "Page: ", default = "1" },
        { key = "box", prompt = "Box x1,y1,x2,y2 (points, origin bottom-left): ", default = "72,72,312,136" },
      }, function(v)
        cb({ "--page", v.page, "--box", v.box })
      end)
    else
      core.run("sign", { "fields", pdf }, {}, function(res)
        local empty = {}
        for line in (res.stdout or ""):gmatch("[^\r\n]+") do
          local name = line:match("^(.*):EMPTY$")
          if name then
            table.insert(empty, name)
          end
        end
        if #empty == 0 then
          return core.notify("no empty signature field in this PDF", vim.log.levels.WARN)
        end
        core.select(empty, { prompt = "Signature field" }, function(name)
          cb({ "--field", name })
        end)
      end)
    end
  end)
end

local function do_sign(pdf, anchor)
  placement(pdf, anchor, function(flags)
    if not flags then
      return
    end
    core.ask({
      { key = "reason", prompt = "Reason: ", default = "I approve this document" },
      {
        key = "mode",
        prompt = "Signature type",
        choices = { "Approval signature", "Certify (no further changes allowed)" },
      },
    }, function(v)
      local args = { "sign", "--reason", v.reason }
      vim.list_extend(args, flags)
      if v.mode:match("^Certify") then
        table.insert(args, "--certify")
      end
      table.insert(args, pdf)

      local env
      if not present(conf_dir() .. "/pdfsign.pass") and (vim.env.DOTS_PDFSIGN_PASS or "") == "" then
        local pass = vim.fn.inputsecret("Certificate passphrase: ")
        if pass == "" then
          return core.notify("cancelled: no passphrase", vim.log.levels.WARN)
        end
        env = { DOTS_PDFSIGN_PASS = pass }
      end

      core.exec("sign", args, {
        label = "signed",
        env = env,
        done = function(out)
          core.run("sign", { "verify", out }, {}, function(res)
            local ok = res.code == 0 and (res.stdout or ""):find("cryptographically sound", 1, true)
            if ok then
              core.notify("signature verified against your certificate")
            else
              core.notify("signed, but verification reported problems: run :Pdf verify", vim.log.levels.WARN)
            end
          end)
        end,
      })
    end)
  end)
end

--- Entry point: <leader>ps / :Pdf sign
function M.sign(pdf, anchor)
  if M.has_cert() then
    return do_sign(pdf, anchor)
  end
  core.select(
    { "Create a local signing certificate", "Cancel" },
    { prompt = "No signing certificate yet" },
    function(choice)
      if choice:match("^Create") then
        M.init(function()
          do_sign(pdf, anchor)
        end)
      end
    end
  )
end

return M
