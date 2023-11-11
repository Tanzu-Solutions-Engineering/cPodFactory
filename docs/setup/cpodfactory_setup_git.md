# Git setup

## set origin and fork
Check current remote 
```
git remote -vvv
```
add fork
```
git remote add fork https://github.com/vEDW/cPodFactory
```

# choose fork / branch

## 

## pull from fork

```
git reset --hard fork/dom-cobb
git pull fork dom-cobb
```

## force pull


## Testing the PR locally


```
git fetch origin pull/ID/head:BRANCHNAME
```

example
```
git fetch origin pull/10/head:demo-feature
git checkout demo-feature
```
