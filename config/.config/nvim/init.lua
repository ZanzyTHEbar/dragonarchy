if os.getenv("SSH_TTY") and not vim.fn.has("clipboard") then
  vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
      if vim.v.event.operator == "y" then
        local encoded = vim.fn.system("base64", vim.fn.getreg('"'))
        encoded = encoded:gsub("\n", "")
        local osc52 = "\x1b]52;c;" .. encoded .. "\x1b\\"
        vim.fn.system("printf " .. vim.fn.shellescape(osc52) .. " > /dev/tty")
      end
    end,
  })
end
