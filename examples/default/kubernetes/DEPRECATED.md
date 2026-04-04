# Deprecated

This directory structure is deprecated. Use the new base+overlay structure:

```bash
# Default deployment
kubectl apply -k ../../kubernetes/overlays/default/

# NBI-auth deployment
kubectl apply -k ../../kubernetes/overlays/nbi-auth/
```

See `examples/kubernetes/` for the new structure.
