-- ⸸ HAIL SATAN - Discord Rich Presence (Modern Implementation) ⸸

return {
    -- Disable old plugins
    {
        "andweeb/presence.nvim",
        enabled = false,
    },
    {
        "IogaMaster/neocord",
        enabled = false,
    },

    -- Enable cord.nvim (most modern and feature-rich)
    {
        "vyfor/cord.nvim",
        build = ":Cord update",
        event = "VeryLazy",
        config = function()
            vim.notify("🔮 Initializing Cord (Modern Discord RPC)...", vim.log.levels.INFO)

            require("cord").setup({
                -- Client/Server settings
                log_level = 'warn', -- Log level
                editor = {
                    image = nil, -- Use default editor image
                    client = 'neovim', -- Editor client name
                    tooltip = '⸸ The One True Editor', -- Tooltip for editor
                },
                display = {
                    theme = 'catppuccin',
                },
                idle = {
                    show_status = false, -- Don't show idle status
                    timeout = 300000,
                    tooltip = '👁️ ',
                },
                text = {
                    viewing = '👁️', -- Reading file
                    editing = '⸸ ⸸', -- Editing file
                    file_browser = '🗂️ Exploring the abyss', -- File browser
                    plugin_manager = '🔌 Managing dark plugins', -- Plugin manager
                    vcs = '📜 Committing dark rituals', -- Version control
                    workspace = '⸸⸸  ⸸⸸', -- Workspace text
                },

            })

            -- Check Discord connection after setup
            vim.defer_fn(function()
                local discord_running = vim.fn.system("pgrep -f discord"):gsub("%s+", "") ~= ""

                if discord_running then
                    vim.notify("✅ Discord detected", vim.log.levels.INFO)
                    vim.notify("👹 Cord Discord presence activated!", vim.log.levels.INFO)
                else
                    vim.notify("❌ Discord not running - start Discord first", vim.log.levels.ERROR)
                end
            end, 2000)
        end,
        keys = {
            {
                "<leader>dp",
                "<cmd>Cord toggle<cr>",
                desc = "Toggle Discord Presence"
            },
            {
                "<leader>dr",
                "<cmd>Cord reconnect<cr>",
                desc = "Reconnect to Discord"
            },
            {
                "<leader>dd",
                function()
                    local discord_running = vim.fn.system("pgrep -f discord"):gsub("%s+", "") ~= ""

                    vim.notify("🔍 Discord Debug Info:", vim.log.levels.INFO)
                    vim.notify("Discord running: " .. (discord_running and "Yes" or "No"), vim.log.levels.INFO)

                    -- Check if Discord is Snap
                    local snap_check = vim.fn.system("snap list discord 2>/dev/null"):gsub("%s+", "")
                    if snap_check ~= "" then
                        vim.notify("✅ Snap Discord detected", vim.log.levels.INFO)
                    else
                        vim.notify("⚠️ Not Snap Discord?", vim.log.levels.WARN)
                    end

                    -- Show Cord status
                    vim.cmd("Cord")
                end,
                desc = "Debug Discord Connection"
            }
        }
    }
}
