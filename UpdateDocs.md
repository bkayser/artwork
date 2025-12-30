https://bkayser.github.io/artwork/

# 1. Create a temporary local branch ('gh-pages-deploy') containing ONLY the 'works' folder
# 2. Force push this temporary branch to the 'gh-pages' branch on GitHub
# 3. Delete the temporary branch

git subtree split --prefix Works -b gh-pages-deploy
git push origin gh-pages-deploy:gh-pages --force
git branch -D gh-pages-deploy