source 'https://api.berkshelf.com'
metadata

group :integration do
  cookbook 'repos',
    git: 'ssh://git@stash.clodo.ru/cook/cookbook-repos.git',
    ref: 'master'

  cookbook 'platform_packages',
    git: 'https://github.com/ClodoCorp/chef-platform_packages.git',
    ref: 'master'
end
