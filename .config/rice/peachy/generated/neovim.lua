return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#1D1218",
        dark_bg    = "#150D12",
        darker_bg  = "#0E090C",
        lighter_bg = "#33292F",

        fg         = "#E5D8F0",
        dark_fg    = "#ABA2B4",
        light_fg   = "#E8DDF2",
        bright_fg  = "#EBE1F3",
        muted      = "#987D8B",

        red        = "#D75551",
        yellow     = "#DAA66C",
        orange     = "#DD6E6B",
        green      = "#73C473",
        cyan       = "#9ED6D6",
        blue       = "#C3C6DA",
        purple     = "#BFA6BF",
        brown      = "#844240",

        bright_red    = "#EC9A98",
        bright_yellow = "#EDCDA9",
        bright_green  = "#AFE1AF",
        bright_cyan   = "#C1E7E7",
        bright_blue   = "#D3D6E5",
        bright_purple = "#D9C9D9",

        accent               = "#C3C6DA",
        cursor               = "#E5D8F0",
        foreground           = "#E5D8F0",
        background           = "#1D1218",
        selection             = "#33292F",
        selection_foreground = "#E5D8F0",
        selection_background = "#33292F",
      },
    },
    -- set up hot reload
    config = function(_, opts)
      require("aether").setup(opts)
      vim.cmd.colorscheme("aether")
      require("aether.hotreload").setup()
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
