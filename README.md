# Nonlinear FEM Wizard — 3D Tetrahedral FEA GUI (MATLAB)

A single-window, step-by-step MATLAB app (`Main_FEM.m`) for 3D linear and
nonlinear static structural finite element analysis on tetrahedral meshes
imported from STL geometry. It merges what were previously two standalone
scripts — a direct **linear** FEA solver and a **nonlinear-to-linear
equivalent-modulus** solver with cellular-solids correction — into one guided
interface, so you no longer have to choose which script to run: the wizard
asks, and adapts.

## 🛠 Features

* **STL Geometry Ingestion** — imports and visualizes 3D `.stl` geometry via
  MATLAB's Partial Differential Equation (PDE) Toolbox.
* **Linear Tetrahedral Meshing** — 4-node solid tetrahedral elements
  (`generateMesh`, linear geometric order).
* **Two analysis regimes, one wizard:**
  * **Linear** — direct isotropic linear-elastic solve from `E` and `ν`.
  * **Nonlinear** — extracts a self-consistent **equivalent secant modulus**
    from a chosen nonlinear constitutive model (calibrated so a one-shot
    linear solve reproduces the correct displacement at the applied force),
    optionally corrected for cellular/lattice geometry via the Gibson-Ashby
    relation, then feeds that modulus into the same linear tetrahedral
    solver.
* **Live embedded results panel** — strain-sweep curve, displacement
  contour, and Von Mises contour render inline (no pop-up figure windows),
  with a one-click **Save Plot** to PNG/JPG/PDF/EPS/FIG.
* **Step-by-step validation** — every input is checked before you can
  advance; failed steps explain what to fix instead of crashing.

## 📐 Mathematical Formulation

### 1. Kinematic Discretization

For each linear 4-node tetrahedral element, the element volume ($V$) is
determined via the determinant of the augmented nodal coordinate matrix:

$$V = \frac{1}{6} \det \begin{bmatrix} 1 & x_1 & y_1 & z_1 \\ 1 & x_2 & y_2 & z_2 \\ 1 & x_3 & y_3 & z_3 \\ 1 & x_4 & y_4 & z_4 \end{bmatrix}$$

The strain-displacement matrix $\mathbf{B}$ maps local nodal displacements
into continuous strain tensors using linear shape-function spatial
derivatives ($\beta_i, \gamma_i, \delta_i$).

### 2. Constitutive Material Matrix

Isotropic material behavior maps into a $6 \times 6$ elasticity matrix
$\mathbf{D}$, built from Young's modulus ($E$) and Poisson's ratio ($\nu$):

$$\mathbf{D} = \frac{E}{(1+\nu)(1-2\nu)} \begin{bmatrix} 1-\nu & \nu & \nu & 0 & 0 & 0 \\ \nu & 1-\nu & \nu & 0 & 0 & 0 \\ \nu & \nu & 1-\nu & 0 & 0 & 0 \\ 0 & 0 & 0 & \frac{1-2\nu}{2} & 0 & 0 \\ 0 & 0 & 0 & 0 & \frac{1-2\nu}{2} & 0 \\ 0 & 0 & 0 & 0 & 0 & \frac{1-2\nu}{2} \end{bmatrix}$$

In the **Linear** regime, $E$ and $\nu$ are used directly as entered. In the
**Nonlinear** regime, $E$ is replaced by the equivalent secant modulus
$E_t$ (or its Gibson-Ashby-corrected counterpart $E_s$) described below.

### 3. Numerical Integration & Assembly

The strain-displacement relationship is constant across a linear
tetrahedron, so the element stiffness matrix reduces to a closed-form
expression:

$$\mathbf{k}_e = V \cdot (\mathbf{B}^T \mathbf{D} \mathbf{B})$$

Local element matrices are accumulated into the sparse global system:

$$\mathbf{K}_{\text{global}} \, \mathbf{d} = \mathbf{F}$$

which is solved after eliminating the fixed-face degrees of freedom.

### 4. Nonlinear Regime: Equivalent Secant Modulus

Rather than a full incremental Newton-Raphson nonlinear solve, the
Nonlinear regime performs:

1. **Strain sweep** — builds a `(strain, force)` table by evaluating the
   chosen model's strain-energy function (or, for the Polynomial model,
   `Force` directly) across a user-specified strain range.
2. **Self-consistent root-find** — solves $F(\varepsilon^*) = F_{\text{applied}}$
   exactly via `fzero`, using the swept table only to locate the correct
   bracket (not a linear-interpolation approximation).
3. **Equivalent modulus extraction** — the secant modulus is computed as
   $E_t = |F_{\text{applied}}| / (A \cdot \varepsilon^*)$: the physically
   correct quantity for a one-shot linear solve to reproduce the *total*
   displacement at that load (as opposed to the local tangent modulus,
   which represents incremental stiffness rather than displacement at a
   given load).
4. **Gibson-Ashby correction** *(optional, cellular/lattice geometries
   only)* — the secant modulus obtained from a lattice specimen's own
   response is an effective *structural* modulus, not a material property.
   The wizard asks whether to convert it to the true constituent material
   modulus via

   $$E_s = \frac{E_{\text{lat}}}{C \cdot (\rho^*/\rho_s)^n}$$

   before it's used as the mesh's material input — this prevents the
   geometric softening from being counted twice (once implicitly in the
   secant, once explicitly by the mesh). Skip this step for solid
   specimens, where the secant modulus already *is* the material modulus.
5. **Linear FEM solve** — assembles the standard isotropic linear-elastic
   tetrahedral stiffness matrix using $E_t$ (or $E_s$), solves the reduced
   system for the applied force, and reconstructs the full displacement
   field.
6. **Post-processing** — Von Mises stress and displacement contours,
   rendered live in the wizard's embedded plot panel.

## Supported constitutive models (Nonlinear regime)

| # | Model | Description |
|---|-------|-------------|
| 1 | Neo-Hookean | `W = μ/2·(I₁-3)` |
| 2 | Mooney-Rivlin | `W = C10·(I₁-3) + C01·(I₂-3)` |
| 3 | Yeoh | `W = C1·(I₁-3) + C2·(I₁-3)² + C3·(I₁-3)³` |
| 4 | EESM (Arruda-Boyce based) | `W = (1-f)·W_iso + f·W_aniso`, matches the Equivalent Energy Spring Model formulation |
| 5 | Phenomenological | Tangent-modulus power series, `E_tan = E₀·(1+ε+ε/α)` |
| 6 | Polynomial | Direct fit of `Force(λ)`, no strain-energy formulation — for use with `fit()`/`fittype('polyN')` results |

The strain-energy sweep and the `fzero` root-find both call the same
internal `F_of_eps` function, so the swept curve shown in the Live Plot
panel and the self-consistent solution can never disagree with each other.
For EESM specifically, the formulation matches the corresponding
curve-fitting routine (`forceExpression.m`) exactly, so parameters obtained
from a `fit()`/`fittype` calibration reproduce the identical force-strain
curve when used here.

## 💻 Getting Started

**Requirements:** MATLAB with the Partial Differential Equation Toolbox.

```matlab
stiffness_gui
```

This opens a single resizable window. Use **Next >** / **< Back** to move
through the steps; each one validates its inputs before letting you
continue.

### Wizard walkthrough

1. **Units, Scale & STL File** — unit system (mm/cm/m), scale factor, and
   the STL geometry to import.
2. **Linear or Nonlinear Regime?** — this determines every step that
   follows.

   **If Nonlinear:**
   3. Mesh Density
   4. Loading Axis & Fixed Face
   5. Applied Force & Cross-Sectional Area
   6. Choose Nonlinear Model
   7. Model Parameters (fields shown depend on the model chosen in step 6;
      EESM can load parameters from a saved `.mat` fit file or accept
      manual entry)
   8. Strain Sweep (self-consistent solve for $\varepsilon^*$ and $E_t$)
   9. Gibson-Ashby Back-Solve (optional — skip to use $E_t$ directly)
   10. Poisson Ratio & FEM Solve
   11. Results & Visualization

   **If Linear:**
   3. Loading Axis & Fixed Face
   4. Applied Force
   5. Material Properties ($E$, $\nu$ — defaults or custom)
   6. FEM Solve
   7. Results & Visualization

### Live Plot panel

Regardless of regime, the right-hand panel stays visible throughout and
shows whichever plot is relevant once computed — Strain Sweep (Nonlinear
only), Displacement, or Von Mises — with **Save Plot...** to export the
current view.

## Inputs

- STL geometry file, unit system, and scale factor
- Mesh density (`Hmax`) or MATLAB default *(Nonlinear regime only — Linear
  regime always uses the default mesh)*
- Loading axis and fixed-face selection
- Applied force (sign convention: negative = compression, positive =
  tension)
- *(Nonlinear only)* Cross-sectional area `A`; constitutive model choice
  and parameters; strain sweep range/resolution; Gibson-Ashby relative
  density, constant, and exponent (if applied)
- *(Linear only)* Young's modulus `E` and Poisson's ratio `ν` directly

## Outputs

- Full nodal displacement field and maximum displacement
- Von Mises stress distribution and its maximum
- *(Nonlinear only)* Self-consistent strain $\varepsilon^*$, equivalent
  modulus $E_t$, and Gibson-Ashby-corrected modulus $E_s$ if applied
- Inline diagnostic plots: strain-energy/force sweep, geometry preview,
  displacement contour, Von Mises contour — each exportable via **Save
  Plot...**

## Notes

- This is a **one-shot linear approximation** in the Nonlinear regime, not
  a full nonlinear finite element solution — it reproduces the correct
  displacement at the specific applied force it was calibrated against,
  but does not track the full incremental nonlinear path.
- The Linear regime is a standard, unmodified isotropic linear-elastic
  solve — no equivalent-modulus machinery is involved.
