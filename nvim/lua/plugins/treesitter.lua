return {
  {"nvim-treesitter/nvim-treesitter", branch = 'main', lazy = false, build = ":TSUpdate",
    config = function()
      local ts = require('nvim-treesitter')
      -- Parser preinstallation is handled by install.sh. Do not block plugin
      -- configuration on downloads here; fresh workspaces can take longer than
      -- Lazy's startup window to compile all parsers.
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-auto', { clear = true }),
        pattern = '*',
        callback = function(ev)
          local ok, task = pcall(ts.install, { ev.match }, { summary = false })
          if not ok then return end
          task:wait(10000)
          pcall(vim.treesitter.start, ev.buf, ev.match)
        end,
      })
    end,
  }
}

