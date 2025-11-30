--- @type LazyPluginSpec[]
return {
  {
    "kaarmu/typst.vim",
    ft = { "typ", "typst" },
    config = function()
      vim.g.typst_pdf_viewer = "skim"
    end,
  }
}
