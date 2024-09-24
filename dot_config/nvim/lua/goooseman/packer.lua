-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'
  use {
	  'nvim-telescope/telescope.nvim', tag = '0.1.8',
	  -- or                            , branch = '0.1.x',
	  requires = { {'nvim-lua/plenary.nvim'} }
  }

  use({
	  'rose-pine/neovim',
	  as = 'rose-pine',
	  config = function()
		  vim.cmd('colorscheme rose-pine')
	  end
  })
  use('nvim-treesitter/nvim-treesitter', {run = ':TSInstall! all'})
  use('nvim-treesitter/playground')
  use('theprimeagen/harpoon')
  use('mbbill/undotree')
  use('ThePrimeagen/vim-be-good')
  use {
	  'Febri-i/snake.nvim',
	  requires = {'Febri-i/fscreen.nvim'},
	  config = function()
		  require('snake').setup({})
	  end
  }
  use { "catppuccin/nvim", as = "catppuccin" }
  use('tpope/vim-fugitive')
end)
