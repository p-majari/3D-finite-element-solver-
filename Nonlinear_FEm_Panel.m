function stiffness_gui()
%STIFFNESS_GUI  Step-by-step wizard for the strain-sweep Eq.28
%   self-consistent secant-modulus solver + tetrahedral FEM analysis.
%
%   Opens a single window and walks through the analysis one step at a
%   time (units -> STL file -> mesh -> boundary conditions ->
%   constitutive model -> strain sweep -> Gibson-Ashby -> FEM solve ->
%   results), the same way a Digital Image Correlation (DIC) wizard
%   such as Ncorr walks a user through Select image -> Set ROI ->
%   Set DIC parameters -> Run -> Post-process.
%
%   Use "Next >" / "< Back" to move between steps. Each step validates
%   its own inputs (and, where needed, runs a calculation) before
%   letting you continue. The underlying math is identical to the
%   original command-line script -- only how the inputs are collected
%   changed, from input()/fprintf prompts to this GUI.

    %% ------------------------------------------------------------------
    %  SHARED STATE
    %% ------------------------------------------------------------------
    P = defaultParams();
    curStep = 1;
    nSteps  = 9;

    stepNames = { ...
        'Step 1: Units, Scale & STL File'
        'Step 2: Mesh Density'
        'Step 3: Loading Axis & Fixed Face'
        'Step 4: Applied Force & Cross-Sectional Area'
        'Step 5: Constitutive Model'
        'Step 6: Strain Sweep (Eq.28 self-consistent solve)'
        'Step 7: Gibson-Ashby Back-Solve'
        'Step 8: Poisson Ratio & FEM Solve'
        'Step 9: Results & Visualization'
        };

    %% ------------------------------------------------------------------
    %  MAIN WINDOW
    %% ------------------------------------------------------------------
    bg  = [0.45 0.06 0.13];   % "wine"/burgundy
    fgText = [1 1 1];         % white label text for contrast against the dark background
    fig = figure('Name','Nonlinear FEM Wizard','NumberTitle','off', ...
        'MenuBar','none','ToolBar','none','Resize','off', ...
        'Position',[80 60 940 720],'Color',bg);

    lblTitle = uicontrol(fig,'Style','text','Units','pixels', ...
        'Position',[20 675 900 30],'FontSize',14,'FontWeight','bold', ...
        'HorizontalAlignment','left','BackgroundColor',bg,'ForegroundColor',fgText, ...
        'String',stepNames{1});

    panels = [];
    for k = 1:nSteps
        panels(k) = uipanel(fig,'Units','pixels','Position',[20 140 900 530], ...
            'BackgroundColor',bg,'BorderType','none','Visible','off');
    end

    logBox = uicontrol(fig,'Style','listbox','Units','pixels', ...
        'Position',[20 20 900 100],'BackgroundColor','white', ...
        'FontName','FixedWidth','FontSize',9,'Max',2,'Min',0,'Value',1, ...
        'String',{'Ready.'});

    btnBack = uicontrol(fig,'Style','pushbutton','String','< Back', ...
        'Units','pixels','Position',[660 128 100 30],'Callback',@onBack);
    btnNext = uicontrol(fig,'Style','pushbutton','String','Next >', ...
        'Units','pixels','Position',[770 128 150 30],'FontWeight','bold', ...
        'Callback',@onNext);

    H = struct();  % all control handles, filled in by buildStepN functions

    buildStep1(); buildStep2(); buildStep3(); buildStep4(); buildStep5();
    buildStep6(); buildStep7(); buildStep8(); buildStep9();

    showStep(1);

    %% ------------------------------------------------------------------
    %  NAVIGATION
    %% ------------------------------------------------------------------
    function onNext(~,~)
        ok = validateStep(curStep);
        if ~ok
            return
        end
        if curStep < nSteps
            curStep = curStep + 1;
            showStep(curStep);
        end
    end

    function onBack(~,~)
        if curStep > 1
            curStep = curStep - 1;
            showStep(curStep);
        end
    end

    function showStep(k)
        for j = 1:nSteps
            set(panels(j),'Visible','off');
        end
        set(panels(k),'Visible','on');
        set(lblTitle,'String',sprintf('%s   (%d/%d)',stepNames{k},k,nSteps));
        set(btnBack,'Enable',onOffStr(k>1));
        if k==9
            updateSummary();
        end
        switch k
            case 6
                set(btnNext,'String','Run Sweep && Continue >');
            case 7
                set(btnNext,'String','Compute E_s && Continue >');
            case 8
                set(btnNext,'String','Run FEM Solve && Continue >');
            case 9
                set(btnNext,'String','Finish');
            otherwise
                set(btnNext,'String','Next >');
        end
    end

    function s = onOffStr(tf)
        if tf, s = 'on'; else, s = 'off'; end
    end

    function logMsg(varargin)
        msg   = sprintf(varargin{:});
        lines = strsplit(msg,{char(10)});
        cur   = get(logBox,'String');
        if ischar(cur), cur = {cur}; end
        cur = [cur(:); lines(:)];
        set(logBox,'String',cur,'Value',numel(cur));
        drawnow;
    end

    %% ------------------------------------------------------------------
    %  SMALL UI HELPERS
    %% ------------------------------------------------------------------
    function h = addLabel(parent,x,y,w,ht,txt)
        h = uicontrol(parent,'Style','text','Units','pixels', ...
            'Position',[x y w ht],'String',txt,'BackgroundColor',bg, ...
            'ForegroundColor',fgText,'HorizontalAlignment','left','FontSize',10);
    end

    function s = dirLabel(idx)
        labs = {'X','Y','Z'};
        s = labs{idx};
    end

    %% ------------------------------------------------------------------
    %  PER-STEP VALIDATION / COMPUTE (dispatch)
    %% ------------------------------------------------------------------
    function ok = validateStep(k)
        ok = true;
        switch k
            case 1, ok = doStep1();
            case 2, ok = doStep2();
            case 3, ok = doStep3();
            case 4, ok = doStep4();
            case 5, ok = doStep5();
            case 6, ok = doStep6();
            case 7, ok = doStep7();
            case 8, ok = doStep8();
            case 9, ok = true;
        end
    end

%% ========================================================================
%  PLACEHOLDER STEP BUILDERS/HANDLERS -- replaced below in later edits
%% ========================================================================

    function buildStep1()
        pnl = panels(1);
        addLabel(pnl,20,470,860,26,'Unit system used by your STL file:');
        H.unitPopup = uicontrol(pnl,'Style','popupmenu','Units','pixels', ...
            'Position',[20 440 300 26], ...
            'String',{'1 - millimetres (mm)','2 - centimetres (cm)','3 - metres (m)'}, ...
            'Value',P.unit_choice);

        addLabel(pnl,20,390,860,26,'STL scale factor (multiplies raw STL coordinates):');
        H.scaleEdit = uicontrol(pnl,'Style','edit','Units','pixels', ...
            'Position',[20 360 150 28],'String',num2str(P.scale_stl), ...
            'BackgroundColor','white','HorizontalAlignment','left');

        addLabel(pnl,20,310,860,26,'STL geometry file:');
        H.stlEdit = uicontrol(pnl,'Style','edit','Units','pixels', ...
            'Position',[20 280 620 28],'String',P.stl_filename, ...
            'BackgroundColor','white','HorizontalAlignment','left');
        H.stlBrowseBtn = uicontrol(pnl,'Style','pushbutton','Units','pixels', ...
            'Position',[650 280 130 28],'String','Browse...', ...
            'Callback',@onBrowseSTL);

        addLabel(pnl,20,230,860,50, ...
            ['Tip: choose the unit system that matches how the STL was ', ...
             'exported (e.g. most 3D printers/CAD tools export in mm). ', ...
             'The scale factor is applied on top of that, e.g. 0.1 to ', ...
             'shrink a model exported 10x too large.']);
    end

    function onBrowseSTL(~,~)
        [f,p] = uigetfile({'*.stl','STL files (*.stl)'},'Select STL geometry file');
        if isequal(f,0), return; end
        set(H.stlEdit,'String',fullfile(p,f));
    end

    function ok = doStep1()
        ok = false;
        uc = get(H.unitPopup,'Value');
        P.unit_choice = uc;
        switch uc
            case 1, P.q=3; P.unit_label='mm';
            case 2, P.q=2; P.unit_label='cm';
            case 3, P.q=0; P.unit_label='m';
        end

        sc = str2double(get(H.scaleEdit,'String'));
        if isnan(sc) || sc<=0
            logMsg('*** Step 1: scale factor must be a positive number.');
            return
        end
        P.scale_stl = sc;

        fname = strtrim(get(H.stlEdit,'String'));
        if isempty(fname)
            logMsg('*** Step 1: please choose an STL file.');
            return
        end
        if length(fname)<4 || ~strcmpi(fname(end-3:end),'.stl')
            fname = [fname,'.stl'];
        end
        if exist(fname,'file')~=2
            logMsg('*** Step 1: file not found: %s',fname);
            return
        end
        P.stl_filename = fname;

        logMsg('Step 1 OK: unit=%s, scale=%.6g, file=%s',P.unit_label,P.scale_stl,P.stl_filename);
        ok = true;
    end

    function buildStep2()
        pnl = panels(2);
        addLabel(pnl,20,470,860,26,'Maximum tetrahedral element edge length, Hmax (metres):');
        addLabel(pnl,20,440,860,26,'Enter 0 to use MATLAB''s default mesh (finest, slowest).');
        H.hmaxEdit = uicontrol(pnl,'Style','edit','Units','pixels', ...
            'Position',[20 400 200 28],'String',num2str(P.Hmax_val), ...
            'BackgroundColor','white','HorizontalAlignment','left');
        addLabel(pnl,20,340,860,50, ...
            ['Smaller Hmax = finer mesh = more accurate but slower. ', ...
             'Start coarse (e.g. Hmax around 1/10 of the smallest feature ', ...
             'size) and refine later if needed.']);
    end

    function ok = doStep2()
        ok = false;
        v = str2double(get(H.hmaxEdit,'String'));
        if isnan(v)
            logMsg('*** Step 2: Hmax must be numeric.');
            return
        end
        if v<=0
            P.use_hmax = false; P.Hmax_val = 0;
            logMsg('Step 2 OK: using MATLAB default mesh.');
        else
            P.use_hmax = true; P.Hmax_val = v;
            logMsg('Step 2 OK: Hmax = %.4g m',v);
        end
        ok = true;
    end
    function buildStep3()
        pnl = panels(3);
        addLabel(pnl,20,470,860,26,'Loading direction (axis along which the force is applied):');
        H.loadAxisPopup = uicontrol(pnl,'Style','popupmenu','Units','pixels', ...
            'Position',[20 440 200 26],'String',{'X','Y','Z'},'Value',P.wu);

        addLabel(pnl,20,380,860,26,'Fixed face (which face is held fixed, at its MIN coordinate):');
        H.fixAxisPopup = uicontrol(pnl,'Style','popupmenu','Units','pixels', ...
            'Position',[20 350 260 26], ...
            'String',{'Same axis as loading','X-min','Y-min','Z-min'},'Value',1);

        addLabel(pnl,20,290,860,60, ...
            ['The load is applied at the MAX-coordinate face along the ', ...
             'loading axis, distributed equally across all nodes on that ', ...
             'face. The fixed face is held at zero displacement.']);
    end

    function ok = doStep3()
        P.wu = get(H.loadAxisPopup,'Value');
        fixSel = get(H.fixAxisPopup,'Value');
        if fixSel==1
            P.fix_wu = P.wu;
        else
            P.fix_wu = fixSel-1;   % 2->X(1) 3->Y(2) 4->Z(3)
        end
        dir_labels = {'X','Y','Z'};
        logMsg('Step 3 OK: load axis=%s, fixed face=%s-min', ...
            dir_labels{P.wu},dir_labels{P.fix_wu});
        ok = true;
    end
    function buildStep4()
        pnl = panels(4);
        addLabel(pnl,20,470,860,26,'Applied total force (N). Negative = compression, positive = tension:');
        H.forceEdit = uicontrol(pnl,'Style','edit','Units','pixels', ...
            'Position',[20 440 200 28],'String',num2str(P.Force), ...
            'BackgroundColor','white','HorizontalAlignment','left');

        addLabel(pnl,20,390,860,26,'Effective cross-sectional area, A (m^2):');
        H.areaEdit = uicontrol(pnl,'Style','edit','Units','pixels', ...
            'Position',[20 360 200 28],'String',num2str(P.AA), ...
            'BackgroundColor','white','HorizontalAlignment','left');
    end

    function ok = doStep4()
        ok = false;
        f = str2double(get(H.forceEdit,'String'));
        if isnan(f)
            logMsg('*** Step 4: force must be numeric.');
            return
        end
        a = str2double(get(H.areaEdit,'String'));
        if isnan(a) || a<=0
            logMsg('*** Step 4: area must be a positive number.');
            return
        end
        P.Force = f; P.AA = a;
        logMsg('Step 4 OK: Force=%.4g N, A=%.4e m^2',P.Force,P.AA);
        ok = true;
    end
    function buildStep5()
        pnl = panels(5);
        addLabel(pnl,20,490,860,26,'Nonlinear constitutive model (its W_T is swept across strain):');
        H.modelPopup = uicontrol(pnl,'Style','popupmenu','Units','pixels', ...
            'Position',[20 460 420 26], ...
            'String',{'1 - Neo-Hookean','2 - Mooney-Rivlin','3 - Yeoh', ...
                       '4 - EESM (Arruda-Boyce)','5 - Phenomenological', ...
                       '6 - Polynomial (direct F(lambda) fit)'}, ...
            'Value',P.hyper_choice,'Callback',@onModelChanged);

        subY = 90; subH = 350;
        H.modelSub = struct();

        % --- 1: Neo-Hookean --------------------------------------------
        s1 = uipanel(pnl,'Units','pixels','Position',[20 subY 860 subH], ...
            'BackgroundColor',bg,'BorderType','none');
        addLabel(s1,0,subH-40,800,26,'W = mu/2*(I1-3)');
        addLabel(s1,0,subH-90,200,26,'mu (Pa):');
        H.nh_mu = uicontrol(s1,'Style','edit','Units','pixels', ...
            'Position',[210 subH-94 200 28],'String',num2str(P.mu_NH),'BackgroundColor','white');
        H.modelSub(1).panel = s1;

        % --- 2: Mooney-Rivlin --------------------------------------------
        s2 = uipanel(pnl,'Units','pixels','Position',[20 subY 860 subH], ...
            'BackgroundColor',bg,'BorderType','none');
        addLabel(s2,0,subH-40,800,26,'W = C10*(I1-3) + C01*(I2-3)');
        addLabel(s2,0,subH-90,200,26,'C10 (Pa):');
        H.mr_c10 = uicontrol(s2,'Style','edit','Units','pixels', ...
            'Position',[210 subH-94 200 28],'String',num2str(P.C10),'BackgroundColor','white');
        addLabel(s2,0,subH-130,200,26,'C01 (Pa):');
        H.mr_c01 = uicontrol(s2,'Style','edit','Units','pixels', ...
            'Position',[210 subH-134 200 28],'String',num2str(P.C01),'BackgroundColor','white');
        H.modelSub(2).panel = s2;

        % --- 3: Yeoh -----------------------------------------------------
        s3 = uipanel(pnl,'Units','pixels','Position',[20 subY 860 subH], ...
            'BackgroundColor',bg,'BorderType','none');
        addLabel(s3,0,subH-40,800,26,'W = C1*(I1-3) + C2*(I1-3)^2 + C3*(I1-3)^3');
        addLabel(s3,0,subH-90,200,26,'C1 (Pa):');
        H.yh_c1 = uicontrol(s3,'Style','edit','Units','pixels', ...
            'Position',[210 subH-94 200 28],'String',num2str(P.C1),'BackgroundColor','white');
        addLabel(s3,0,subH-130,200,26,'C2 (Pa):');
        H.yh_c2 = uicontrol(s3,'Style','edit','Units','pixels', ...
            'Position',[210 subH-134 200 28],'String',num2str(P.C2),'BackgroundColor','white');
        addLabel(s3,0,subH-170,200,26,'C3 (Pa):');
        H.yh_c3 = uicontrol(s3,'Style','edit','Units','pixels', ...
            'Position',[210 subH-174 200 28],'String',num2str(P.C3),'BackgroundColor','white');
        H.modelSub(3).panel = s3;

        % --- 4: EESM -------------------------------------------------
        s4 = uipanel(pnl,'Units','pixels','Position',[20 subY 860 subH], ...
            'BackgroundColor',bg,'BorderType','none');
        addLabel(s4,0,subH-40,800,26,'EESM (Arruda-Boyce): WT = (1-f)*Wiso + f*Waniso');
        H.eesmSourcePopup = uicontrol(s4,'Style','popupmenu','Units','pixels', ...
            'Position',[0 subH-80 420 26], ...
            'String',{'Load from fitted .mat file (recommended)','Manual entry'}, ...
            'Value',1,'Callback',@onEesmSourceChanged);

        % -- 4a: load-from-file sub-controls
        H.eesmFileEdit = uicontrol(s4,'Style','edit','Units','pixels', ...
            'Position',[0 subH-120 600 28],'String','eesm_fitted_params.mat', ...
            'BackgroundColor','white','HorizontalAlignment','left');
        H.eesmFileBrowseBtn = uicontrol(s4,'Style','pushbutton','Units','pixels', ...
            'Position',[610 subH-120 130 28],'String','Browse...', ...
            'Callback',@onBrowseEesmMat);

        % -- 4b: manual-entry sub-controls
        mx = 0; my = subH-160; dy = 38;
        addLabel(s4,mx,my,120,26,'mu (Pa):');
        H.eesm_mu = uicontrol(s4,'Style','edit','Units','pixels', ...
            'Position',[mx+130 my-2 150 28],'String',num2str(P.mu_AB),'BackgroundColor','white');
        addLabel(s4,mx+300,my,120,26,'N:');
        H.eesm_N = uicontrol(s4,'Style','edit','Units','pixels', ...
            'Position',[mx+340 my-2 150 28],'String',num2str(P.N_AB),'BackgroundColor','white');
        my = my-dy;
        addLabel(s4,mx,my,120,26,'A1 (Pa):');
        H.eesm_A1 = uicontrol(s4,'Style','edit','Units','pixels', ...
            'Position',[mx+130 my-2 150 28],'String',num2str(P.A1_AB),'BackgroundColor','white');
        addLabel(s4,mx+300,my,120,26,'A2 (Pa):');
        H.eesm_A2 = uicontrol(s4,'Style','edit','Units','pixels', ...
            'Position',[mx+340 my-2 150 28],'String',num2str(P.A2_AB),'BackgroundColor','white');
        my = my-dy;
        addLabel(s4,mx,my,120,26,'f (0 to 1):');
        H.eesm_f = uicontrol(s4,'Style','edit','Units','pixels', ...
            'Position',[mx+130 my-2 150 28],'String',num2str(P.f_AB),'BackgroundColor','white');
        H.modelSub(4).panel = s4;
        H.eesmManualHandles = [H.eesm_mu H.eesm_N H.eesm_A1 H.eesm_A2 H.eesm_f];
        H.eesmFileHandles   = [H.eesmFileEdit H.eesmFileBrowseBtn];

        % --- 5: Phenomenological ------------------------------------------
        s5 = uipanel(pnl,'Units','pixels','Position',[20 subY 860 subH], ...
            'BackgroundColor',bg,'BorderType','none');
        addLabel(s5,0,subH-40,800,26,'Phenomenological: Etan = E0*(1+eps+eps/alpha)');
        addLabel(s5,0,subH-90,200,26,'E (Pa):');
        H.ph_E = uicontrol(s5,'Style','edit','Units','pixels', ...
            'Position',[210 subH-94 200 28],'String',num2str(P.EE),'BackgroundColor','white');
        addLabel(s5,0,subH-130,200,26,'alpha:');
        H.ph_alpha = uicontrol(s5,'Style','edit','Units','pixels', ...
            'Position',[210 subH-134 200 28],'String',num2str(P.alpha_phen),'BackgroundColor','white');
        H.modelSub(5).panel = s5;

        % --- 6: Polynomial -------------------------------------------------
        s6 = uipanel(pnl,'Units','pixels','Position',[20 subY 860 subH], ...
            'BackgroundColor',bg,'BorderType','none');
        addLabel(s6,0,subH-40,800,40, ...
            ['Polynomial: F(lambda) = p1*lambda^d + ... + p(d+1). Direct fit ', ...
             'of Force vs lambda (MATLAB fit(), fittype=''polyN'').']);
        addLabel(s6,0,subH-90,200,26,'Degree d:');
        H.poly_degree = uicontrol(s6,'Style','edit','Units','pixels', ...
            'Position',[210 subH-94 80 28],'String',num2str(P.poly_degree),'BackgroundColor','white');
        H.poly_applyBtn = uicontrol(s6,'Style','pushbutton','Units','pixels', ...
            'Position',[310 subH-94 160 28],'String','Apply degree', ...
            'Callback',@onApplyPolyDegree);
        maxCoeffs = 11;
        H.poly_coeffEdits = cell(1,maxCoeffs);
        for ci = 1:maxCoeffs
            row = floor((ci-1)/4); col = mod(ci-1,4);
            addLabel(s6,col*210,subH-140-row*40,60,24,sprintf('p%d:',ci));
            H.poly_coeffEdits{ci} = uicontrol(s6,'Style','edit','Units','pixels', ...
                'Position',[col*210+50 subH-142-row*40 140 26], ...
                'String','0','BackgroundColor','white');
        end
        H.modelSub(6).panel = s6;

        onModelChanged();     % show the right sub-panel for the default model
        onEesmSourceChanged();
        onApplyPolyDegree();
    end

    function onModelChanged(~,~)
        sel = get(H.modelPopup,'Value');
        for j = 1:numel(H.modelSub)
            set(H.modelSub(j).panel,'Visible',onOffStr(j==sel));
        end
    end

    function onEesmSourceChanged(~,~)
        src = get(H.eesmSourcePopup,'Value');   % 1=file, 2=manual
        set(H.eesmFileHandles,  'Visible',onOffStr(src==1));
        set(H.eesmManualHandles,'Visible',onOffStr(src==2));
    end

    function onBrowseEesmMat(~,~)
        [f,p] = uigetfile({'*.mat','MAT files (*.mat)'},'Select fitted EESM parameter file');
        if isequal(f,0), return; end
        set(H.eesmFileEdit,'String',fullfile(p,f));
    end

    function onApplyPolyDegree(~,~)
        d = round(str2double(get(H.poly_degree,'String')));
        if isnan(d) || d<0, d = 0; end
        maxCoeffs = numel(H.poly_coeffEdits);
        d = min(d,maxCoeffs-1);
        for ci = 1:maxCoeffs
            set(H.poly_coeffEdits{ci},'Visible',onOffStr(ci<=d+1));
        end
    end

    function ok = doStep5()
        ok = false;
        hc = get(H.modelPopup,'Value');
        P.hyper_choice = hc;
        dir_labels = {'X','Y','Z'}; %#ok<NASGU>
        switch hc
            case 1
                mu = str2double(get(H.nh_mu,'String'));
                if isnan(mu), logMsg('*** Step 5: mu must be numeric.'); return; end
                P.mu_NH = mu;
                P.hyper_label = sprintf('Neo-Hookean  mu=%.4g Pa',mu);
            case 2
                c10 = str2double(get(H.mr_c10,'String'));
                c01 = str2double(get(H.mr_c01,'String'));
                if any(isnan([c10 c01])), logMsg('*** Step 5: C10/C01 must be numeric.'); return; end
                P.C10 = c10; P.C01 = c01;
                P.hyper_label = sprintf('Mooney-Rivlin  C10=%.4g C01=%.4g Pa',c10,c01);
            case 3
                c1 = str2double(get(H.yh_c1,'String'));
                c2 = str2double(get(H.yh_c2,'String'));
                c3 = str2double(get(H.yh_c3,'String'));
                if any(isnan([c1 c2 c3])), logMsg('*** Step 5: C1/C2/C3 must be numeric.'); return; end
                P.C1=c1; P.C2=c2; P.C3=c3;
                P.hyper_label = sprintf('Yeoh  C1=%.4g C2=%.4g C3=%.4g Pa',c1,c2,c3);
            case 4
                src = get(H.eesmSourcePopup,'Value');
                if src==1
                    fit_file = strtrim(get(H.eesmFileEdit,'String'));
                    if exist(fit_file,'file')~=2
                        logMsg('*** Step 5: fitted parameter file not found: %s',fit_file);
                        return
                    end
                    S = load(fit_file);
                    P.mu_AB=S.eesm_mu; P.N_AB=S.eesm_N; P.A1_AB=S.eesm_A1;
                    P.A2_AB=S.eesm_A2; P.f_AB=S.eesm_f; P.c_AB=S.eesm_c;
                    logMsg('Step 5: loaded EESM params from %s',fit_file);
                else
                    mu=str2double(get(H.eesm_mu,'String'));
                    N =str2double(get(H.eesm_N,'String'));
                    A1=str2double(get(H.eesm_A1,'String'));
                    A2=str2double(get(H.eesm_A2,'String'));
                    f =str2double(get(H.eesm_f,'String'));
                    if any(isnan([mu N A1 A2 f]))
                        logMsg('*** Step 5: mu/N/A1/A2/f must be numeric.');
                        return
                    end
                    lam_r0_c = 1/sqrt(N);
                    beta0_c  = 3*lam_r0_c/(1-lam_r0_c^3);
                    c_auto = -mu*(N*(beta0_c*lam_r0_c+log(beta0_c/sinh(beta0_c)))-log(beta0_c/lam_r0_c));
                    P.mu_AB=mu; P.N_AB=N; P.A1_AB=A1; P.A2_AB=A2; P.f_AB=f; P.c_AB=c_auto;
                end
                P.hyper_label = sprintf('EESM  mu=%.4g N=%.4g A1=%.4g A2=%.4g c=%.4g f=%.4g', ...
                    P.mu_AB,P.N_AB,P.A1_AB,P.A2_AB,P.c_AB,P.f_AB);
            case 5
                E = str2double(get(H.ph_E,'String'));
                al = str2double(get(H.ph_alpha,'String'));
                if any(isnan([E al])), logMsg('*** Step 5: E/alpha must be numeric.'); return; end
                P.EE = E; P.alpha_phen = al;
                P.hyper_label = sprintf('Phenomenological  E=%.4g alpha=%.4g',E,al);
            case 6
                d = round(str2double(get(H.poly_degree,'String')));
                if isnan(d) || d<0, logMsg('*** Step 5: degree must be a non-negative integer.'); return; end
                coeffs = zeros(1,d+1);
                for ci = 1:d+1
                    coeffs(ci) = str2double(get(H.poly_coeffEdits{ci},'String'));
                end
                if any(isnan(coeffs)), logMsg('*** Step 5: all polynomial coefficients must be numeric.'); return; end
                P.poly_degree = d; P.poly_coeffs = coeffs;
                P.hyper_label = sprintf('Polynomial (degree %d): %s',d,mat2str(coeffs));
        end
        logMsg('Step 5 OK: model = %s',P.hyper_label);
        ok = true;
    end
    function buildStep6()
        pnl = panels(6);
        addLabel(pnl,20,470,860,26, ...
            'Maximum strain for the sweep (eps). Try 0.95 for compression, 3-5 for tension:');
        H.epsMaxEdit = uicontrol(pnl,'Style','edit','Units','pixels', ...
            'Position',[20 440 150 28],'String',num2str(P.eps_sweep_max),'BackgroundColor','white');

        addLabel(pnl,20,390,860,26,'Number of sweep points:');
        H.nSweepEdit = uicontrol(pnl,'Style','edit','Units','pixels', ...
            'Position',[20 360 150 28],'String',num2str(P.n_sweep),'BackgroundColor','white');

        addLabel(pnl,20,290,860,60, ...
            ['Clicking "Run Sweep && Continue" below builds the Force-strain ', ...
             'table for your chosen model, finds the self-consistent strain ', ...
             'eps* at which the model matches your applied force, and ', ...
             'computes the secant modulus E_t. A diagnostic plot opens in a new window.']);

        H.sweepResultText = uicontrol(pnl,'Style','text','Units','pixels', ...
            'Position',[20 200 860 60],'String','(not yet run)', ...
            'BackgroundColor','white','HorizontalAlignment','left','FontName','FixedWidth');
    end

    function ok = doStep6()
        ok = false;
        esm = str2double(get(H.epsMaxEdit,'String'));
        ns  = round(str2double(get(H.nSweepEdit,'String')));
        if isnan(esm) || esm<=0
            logMsg('*** Step 6: max eps must be a positive number.');
            return
        end
        if isnan(ns) || ns<10
            logMsg('*** Step 6: number of sweep points must be >= 10.');
            return
        end
        P.eps_sweep_max = esm; P.n_sweep = ns;

        logMsg('Step 6: running strain sweep (%d points, eps up to %.4g)...',ns,esm);
        drawnow;

        sign_F = sign(P.Force);
        if sign_F==0, sign_F = 1; end

        eps_sweep = linspace(1e-5,esm,ns)';
        F_sweep  = zeros(ns,1);
        WT_sweep = zeros(ns,1);
        for kk = 1:ns
            [F_sweep(kk),WT_sweep(kk)] = F_of_eps(eps_sweep(kk),P.hyper_choice,sign_F,P.AA, ...
                P.mu_NH,P.C10,P.C01,P.C1,P.C2,P.C3, ...
                P.mu_AB,P.N_AB,P.A1_AB,P.A2_AB,P.c_AB,P.f_AB,P.EE,P.alpha_phen,P.poly_coeffs);
        end

        target_F = P.Force;
        resid = F_sweep - target_F;
        eps_star = NaN; bracket_lo = NaN; bracket_hi = NaN;
        for kk = 1:ns-1
            if isfinite(resid(kk)) && isfinite(resid(kk+1)) && sign(resid(kk))~=sign(resid(kk+1))
                bracket_lo = eps_sweep(kk); bracket_hi = eps_sweep(kk+1);
                break
            end
        end

        if ~isnan(bracket_lo)
            Fh = @(e) F_of_eps(e,P.hyper_choice,sign_F,P.AA,P.mu_NH,P.C10,P.C01,P.C1,P.C2,P.C3, ...
                P.mu_AB,P.N_AB,P.A1_AB,P.A2_AB,P.c_AB,P.f_AB,P.EE,P.alpha_phen,P.poly_coeffs) - target_F;
            fzopts = optimset('TolX',1e-12,'Display','off');
            eps_star = fzero(Fh,[bracket_lo,bracket_hi],fzopts);
            logMsg('  eps* = %.6f (%.2f%%)  [exact root via fzero]',eps_star,eps_star*100);
        else
            [~,idxMin] = min(abs(resid));
            eps_star = eps_sweep(idxMin);
            logMsg('  *** no sign change found in range; using closest match eps*=%.6f',eps_star);
        end

        E_t = abs(target_F)/(P.AA*max(eps_star,1e-9));
        if E_t < 1e3
            logMsg('  *** NOTE: E_t floored at 1e3 Pa (computed value was too small).');
        end
        E_t = max(E_t,1e3);

        P.eps_star = eps_star;
        P.E_t   = E_t;
        P.E_lat = E_t;

        figure('Name','Eq.28 Force-Strain Table','NumberTitle','off');
        subplot(2,1,1);
        plot(eps_sweep,WT_sweep,'b-','LineWidth',1.5);
        xlabel('\epsilon'); ylabel('W_T (Pa)'); title('Strain-energy density vs strain'); grid on;
        subplot(2,1,2);
        plot(eps_sweep,F_sweep,'r-','LineWidth',1.5); hold on;
        plot([eps_sweep(1) eps_sweep(end)],[target_F target_F],'--k','LineWidth',1.2);
        legend({'F(\epsilon)',sprintf('Force=%.4g N',target_F)},'Location','best');
        xlabel('\epsilon'); ylabel('F (N)'); title('Force vs strain (swept, signed)'); grid on;

        set(H.sweepResultText,'String', ...
            {sprintf('eps* = %.6f (%.2f%%)',eps_star,eps_star*100), ...
             sprintf('E_lat (secant modulus) = %.4f Pa (%.4f MPa)',E_t,E_t/1e6)});

        logMsg('Step 6 OK: eps*=%.6f, E_lat=%.4f Pa (%.4f MPa)',eps_star,E_t,E_t/1e6);
        P.sweepDone = true;
        ok = true;
    end
    function buildStep7()
        pnl = panels(7);
        addLabel(pnl,20,470,860,50, ...
            ['Back-solve the constituent solid modulus E_s from the lattice''s ', ...
             'own effective (secant) modulus E_lat found in Step 6:  ', ...
             'E_s = E_lat / (C * (rho/rho_s)^n)']);

        addLabel(pnl,20,410,200,26,'C (Gibson-Ashby constant, often ~1):');
        H.gaC = uicontrol(pnl,'Style','edit','Units','pixels', ...
            'Position',[300 410 150 28],'String',num2str(P.C_GA),'BackgroundColor','white');

        addLabel(pnl,20,370,260,26,'Relative density, rho/rho_s (0 to 1):');
        H.gaRho = uicontrol(pnl,'Style','edit','Units','pixels', ...
            'Position',[300 370 150 28],'String',num2str(P.rho_ratio),'BackgroundColor','white');

        addLabel(pnl,20,330,260,26,'Exponent n (~1.5-2 for bending-dominated lattices):');
        H.gaN = uicontrol(pnl,'Style','edit','Units','pixels', ...
            'Position',[300 330 150 28],'String',num2str(P.n_GA),'BackgroundColor','white');

        H.gaResultText = uicontrol(pnl,'Style','text','Units','pixels', ...
            'Position',[20 250 860 60],'String','(not yet computed)', ...
            'BackgroundColor','white','HorizontalAlignment','left','FontName','FixedWidth');

        addLabel(pnl,20,180,860,50, ...
            ['E_s is the property with the lattice geometry removed -- this is ', ...
             'what gets fed into the FEM solve in Step 8, since the mesh ', ...
             'itself reintroduces the correct structural dilution from the ', ...
             'real 3D geometry.']);
    end

    function ok = doStep7()
        ok = false;
        if ~P.sweepDone
            logMsg('*** Step 7: please complete Step 6 (strain sweep) first.');
            return
        end
        C   = str2double(get(H.gaC,'String'));
        rho = str2double(get(H.gaRho,'String'));
        n   = str2double(get(H.gaN,'String'));
        if any(isnan([C rho n])) || rho<=0 || rho>1 || C<=0
            logMsg('*** Step 7: C (>0), rho/rho_s (0 to 1], and n must be valid numbers.');
            return
        end
        P.C_GA = C; P.rho_ratio = rho; P.n_GA = n;
        P.E_s = P.E_lat/(C*(rho^n));

        set(H.gaResultText,'String', ...
            {sprintf('E_lat = %.4f Pa (%.4f MPa)',P.E_lat,P.E_lat/1e6), ...
             sprintf('E_s   = E_lat/(C*(rho/rho_s)^n) = %.4f Pa (%.4f MPa)',P.E_s,P.E_s/1e6)});

        logMsg('Step 7 OK: E_s = %.4f Pa (%.4f MPa)',P.E_s,P.E_s/1e6);
        P.gaDone = true;
        ok = true;
    end
    function buildStep8()
        pnl = panels(8);
        addLabel(pnl,20,470,860,26,'Poisson ratio, nu (used in the linear D matrix):');
        H.nuEdit = uicontrol(pnl,'Style','edit','Units','pixels', ...
            'Position',[20 440 150 28],'String',num2str(P.nu_input),'BackgroundColor','white');

        addLabel(pnl,20,380,860,50, ...
            ['Clicking "Run FEM Solve && Continue" imports the STL geometry, ', ...
             'generates the tetrahedral mesh, assembles the global stiffness ', ...
             'matrix using E_s from Step 7, and solves for displacements and ', ...
             'von Mises stress. This can take a while for fine meshes -- ', ...
             'progress is reported in the log box below.']);

        H.solveResultText = uicontrol(pnl,'Style','text','Units','pixels', ...
            'Position',[20 200 860 130],'String','(not yet run)', ...
            'BackgroundColor','white','HorizontalAlignment','left','FontName','FixedWidth');
    end

    function ok = doStep8()
        ok = false;
        if ~P.gaDone
            logMsg('*** Step 8: please complete Step 7 (Gibson-Ashby) first.');
            return
        end
        nu = str2double(get(H.nuEdit,'String'));
        if isnan(nu) || nu<=-1 || nu>=0.5
            logMsg('*** Step 8: Poisson ratio must be in the range (-1, 0.5).');
            return
        end
        P.nu_input = nu;

        try
            logMsg('Step 8: importing geometry from %s ...',P.stl_filename);
            drawnow;
            smodel = createpde('structural','static-solid');
            importGeometry(smodel,P.stl_filename);
            figure('Name','Geometry','NumberTitle','off');
            pdegplot(smodel); view(30,30); title(['Geometry: ',P.stl_filename]);

            logMsg('Step 8: generating mesh ...'); drawnow;
            if P.use_hmax
                model = generateMesh(smodel,'GeometricOrder','linear','Hmax',P.Hmax_val);
            else
                model = generateMesh(smodel,'GeometricOrder','linear');
            end
            nodeCoordinates = model.Nodes;
            connectivity    = model.Elements;
            numNodes = size(nodeCoordinates,2);
            numElem  = size(connectivity,2);
            ndof     = 3*numNodes;
            logMsg('  Nodes=%d   Elements=%d',numNodes,numElem);

            coords_m = nodeCoordinates*P.scale_stl*10^(-P.q);

            xc = zeros(4,numElem); yc = zeros(4,numElem); zc = zeros(4,numElem);
            for i = 1:numElem
                for j = 1:4
                    n = connectivity(j,i);
                    xc(j,i) = coords_m(1,n); yc(j,i) = coords_m(2,n); zc(j,i) = coords_m(3,n);
                end
            end

            order_fit = 10;
            load_coord   = coords_m(P.wu,:);
            load_max     = round(max(load_coord),order_fit);
            load_Indices = find(load_coord>=load_max-1e-6*abs(load_max));

            fixed_coord   = coords_m(P.fix_wu,:);
            fixed_min     = round(min(fixed_coord),order_fit);
            fixed_Indices = find(fixed_coord<=fixed_min+1e-6*abs(fixed_min)+1e-12);

            fixedDOFs = reshape([3*fixed_Indices(:)'-2;3*fixed_Indices(:)'-1;3*fixed_Indices(:)'],1,[]);
            freeDOFs  = setdiff(1:ndof,fixedDOFs);

            logMsg('  Load nodes=%d (%s-max)   Fixed nodes=%d (%s-min)', ...
                numel(load_Indices),dirLabel(P.wu),numel(fixed_Indices),dirLabel(P.fix_wu));

            logMsg('Step 8: computing element B-matrices ...'); drawnow;
            B_all = cell(numElem,1); V_all = zeros(numElem,1);
            for jj = 1:numElem
                x1=xc(1,jj);x2=xc(2,jj);x3=xc(3,jj);x4=xc(4,jj);
                y1=yc(1,jj);y2=yc(2,jj);y3=yc(3,jj);y4=yc(4,jj);
                z1=zc(1,jj);z2=zc(2,jj);z3=zc(3,jj);z4=zc(4,jj);

                v6 = det([1 x1 y1 z1;1 x2 y2 z2;1 x3 y3 z3;1 x4 y4 z4]);
                Ve = abs(v6)/6; V_all(jj) = Ve; sc = 1/(6*Ve);

                b1=-((y3-y2)*(z4-z2)-(y4-y2)*(z3-z2));
                g1=-((x4-x2)*(z3-z2)-(x3-x2)*(z4-z2));
                d1=-((x3-x2)*(y4-y2)-(x4-x2)*(y3-y2));
                b2= (y3-y1)*(z4-z1)-(y4-y1)*(z3-z1);
                g2= (x4-x1)*(z3-z1)-(x3-x1)*(z4-z1);
                d2= (x3-x1)*(y4-y1)-(x4-x1)*(y3-y1);
                b3=-((y2-y1)*(z4-z1)-(y4-y1)*(z2-z1));
                g3=-((x4-x1)*(z2-z1)-(x2-x1)*(z4-z1));
                d3=-((x2-x1)*(y4-y1)-(x4-x1)*(y2-y1));
                b4= (y2-y1)*(z3-z1)-(y3-y1)*(z2-z1);
                g4= (x3-x1)*(z2-z1)-(x2-x1)*(z3-z1);
                d4= (x2-x1)*(y3-y1)-(x3-x1)*(y2-y1);

                Bi = @(b,g,d) sc*[b 0 0;0 g 0;0 0 d;g b 0;0 d g;d 0 b];
                B_all{jj} = [Bi(b1,g1,d1) Bi(b2,g2,d2) Bi(b3,g3,d3) Bi(b4,g4,d4)];
            end

            c_lin = P.E_s/((1+nu)*(1-2*nu));
            D_lin = c_lin*[1-nu nu   nu   0        0        0;
                           nu   1-nu nu   0        0        0;
                           nu   nu   1-nu 0        0        0;
                           0    0    0    (1-2*nu)/2 0        0;
                           0    0    0    0        (1-2*nu)/2 0;
                           0    0    0    0        0        (1-2*nu)/2];

            logMsg('Step 8: assembling global stiffness matrix (using E_s) ...'); drawnow;
            force_full = zeros(ndof,1);
            for n = load_Indices(:)'
                force_full(3*(n-1)+P.wu) = P.Force/numel(load_Indices);
            end
            global_K = sparse(ndof,ndof);
            for jj = 1:numElem
                ns_   = connectivity(:,jj);
                dof_e = reshape([3*ns_-2,3*ns_-1,3*ns_]',1,[]);
                Ve    = V_all(jj); BB_e = B_all{jj};
                global_K(dof_e,dof_e) = global_K(dof_e,dof_e) + Ve*(BB_e'*D_lin*BB_e);
            end

            logMsg('Step 8: solving linear system ...'); drawnow;
            u_total = zeros(ndof,1);
            u_total(freeDOFs) = global_K(freeDOFs,freeDOFs)\force_full(freeDOFs);

            disp_in_dir = u_total(P.wu:3:end);
            max_disp    = max(abs(disp_in_dir));

            vm_stress = zeros(numElem,1);
            for jj = 1:numElem
                ns_   = connectivity(:,jj);
                dof_e = reshape([3*ns_-2,3*ns_-1,3*ns_]',1,[]);
                sig   = D_lin*B_all{jj}*u_total(dof_e);
                sxx=sig(1);syy=sig(2);szz=sig(3);txy=sig(4);tyz=sig(5);txz=sig(6);
                vm_stress(jj) = sqrt(0.5*((sxx-syy)^2+(syy-szz)^2+(szz-sxx)^2 ...
                                           +6*(txy^2+tyz^2+txz^2)));
            end
            node_vm = zeros(numNodes,1); nc1 = zeros(numNodes,1);
            for jj = 1:numElem
                ns_ = connectivity(:,jj);
                node_vm(ns_) = node_vm(ns_)+vm_stress(jj); nc1(ns_) = nc1(ns_)+1;
            end
            node_vm = node_vm./max(nc1,1);

            all_faces = [connectivity([1 2 3],:)';connectivity([1 2 4],:)'; ...
                         connectivity([1 3 4],:)';connectivity([2 3 4],:)'];
            all_faces = sort(all_faces,2);
            [~,ia,ic]   = unique(all_faces,'rows');
            face_counts = accumarray(ic,1);
            surf_faces  = all_faces(ia(face_counts==1),:);
            surf_verts  = coords_m';

            P.numNodes = numNodes; P.numElem = numElem;
            P.max_disp = max_disp; P.node_vm = node_vm;
            P.disp_in_dir = disp_in_dir;
            P.surf_verts = surf_verts; P.surf_faces = surf_faces;

            set(H.solveResultText,'String', ...
                {sprintf('Nodes=%d  Elements=%d',numNodes,numElem), ...
                 sprintf('Max disp (%s) = %.6g m = %.4g mm',dirLabel(P.wu),max_disp,max_disp*1e3), ...
                 sprintf('Max Von Mises = %.4g Pa = %.4g kPa',max(node_vm),max(node_vm)*1e-3)});

            logMsg('Step 8 OK: max disp=%.4g mm, max von Mises=%.4g kPa', ...
                max_disp*1e3, max(node_vm)*1e-3);
            P.femDone = true;
            ok = true;
        catch ME
            logMsg('*** Step 8 FAILED: %s',ME.message);
            ok = false;
        end
    end
    function buildStep9()
        pnl = panels(9);
        H.chkDisp = uicontrol(pnl,'Style','checkbox','Units','pixels', ...
            'Position',[20 480 400 26],'String','Show displacement contour','Value',1, ...
            'BackgroundColor',bg,'ForegroundColor',fgText);
        H.chkVM = uicontrol(pnl,'Style','checkbox','Units','pixels', ...
            'Position',[20 445 400 26],'String','Show von Mises stress contour','Value',1, ...
            'BackgroundColor',bg,'ForegroundColor',fgText);
        H.showPlotsBtn = uicontrol(pnl,'Style','pushbutton','Units','pixels', ...
            'Position',[20 395 240 32],'String','Show Selected Plots','FontWeight','bold', ...
            'Callback',@onShowPlots);

        addLabel(pnl,20,350,860,26,'Results summary:');
        H.summaryText = uicontrol(pnl,'Style','text','Units','pixels', ...
            'Position',[20 40 860 300],'String',{'Complete Step 8 first to see results here.'}, ...
            'BackgroundColor','white','HorizontalAlignment','left','FontName','FixedWidth', ...
            'FontSize',10);
    end

    function onShowPlots(~,~)
        if ~P.femDone
            logMsg('*** Please complete Step 8 (FEM solve) first.');
            return
        end
        if get(H.chkDisp,'Value')
            ttl = sprintf('Displacement-%s (mm)',dirLabel(P.wu));
            figure('Name',ttl,'NumberTitle','off');
            patch('Vertices',P.surf_verts,'Faces',P.surf_faces, ...
                'FaceVertexCData',P.disp_in_dir*1e3,'FaceColor','interp','EdgeColor','none');
            colormap jet; cb = colorbar; cb.Label.String = sprintf('u%s (mm)',lower(dirLabel(P.wu)));
            title(ttl); view(30,30); axis equal tight;
            xlabel('X(m)'); ylabel('Y(m)'); zlabel('Z(m)');
            lighting gouraud; camlight;
        end
        if get(H.chkVM,'Value')
            figure('Name','Von Mises (kPa)','NumberTitle','off');
            patch('Vertices',P.surf_verts,'Faces',P.surf_faces, ...
                'FaceVertexCData',P.node_vm*1e-3,'FaceColor','interp','EdgeColor','none');
            colormap jet; cb = colorbar; cb.Label.String = 'Von Mises (kPa)';
            caxis([0, prctile(P.node_vm,98)/1e3]);
            title('Von Mises Stress (kPa)'); view(30,30); axis equal tight;
            xlabel('X(m)'); ylabel('Y(m)'); zlabel('Z(m)');
            lighting gouraud; camlight;
        end
        updateSummary();
    end

    function updateSummary()
        if ~P.femDone
            return
        end
        lines = { ...
            sprintf('Model               : %s',P.hyper_label), ...
            sprintf('eps* (self-consistent): %.6f (%.2f%%)',P.eps_star,P.eps_star*100), ...
            sprintf('E_lat (lattice secant): %.4f Pa (%.4f MPa)',P.E_lat,P.E_lat/1e6), ...
            sprintf('E_s (Gibson-Ashby)  : %.4f Pa (%.4f MPa)',P.E_s,P.E_s/1e6), ...
            sprintf('Applied Force       : %.4g N (%s)',P.Force,dirLabel(P.wu)), ...
            sprintf('Nodes / Elements    : %d / %d',P.numNodes,P.numElem), ...
            sprintf('Max disp (%s)        : %.6g m = %.4g mm',dirLabel(P.wu),P.max_disp,P.max_disp*1e3), ...
            sprintf('Max Von Mises       : %.4g Pa = %.4g kPa',max(P.node_vm),max(P.node_vm)*1e-3) ...
            };
        set(H.summaryText,'String',lines);
    end

end

%% ============================================================================
%  CONSTITUTIVE-MODEL FORCE-STRAIN RELATION (identical to the original
%  command-line script -- used both by the sweep loop and by fzero for
%  the exact self-consistent root eps*, so they can never disagree).
%% ============================================================================
function [F, WT_k] = F_of_eps(eps_k, hc, sign_F, AA, ...
                              mu_NH,C10,C01,C1,C2,C3,...
                              mu_AB,N_AB,A1_AB,A2_AB,c_AB,f_AB,EE,alpha_phen,poly_coeffs)
    lam   = 1 + sign_F*eps_k;
    lam2  = 1/sqrt(lam);
    I1    = lam^2 + 2*lam2^2;
    I2    = 2*lam + 1/lam^2;

    switch hc
        case 1
            WT_k = mu_NH/2*(I1-3);
            F = sign_F*2*AA*abs(WT_k)/max(eps_k,1e-9);
        case 2
            WT_k = C10*(I1-3) + C01*(I2-3);
            F = sign_F*2*AA*abs(WT_k)/max(eps_k,1e-9);
        case 3
            WT_k = C1*(I1-3) + C2*(I1-3)^2 + C3*(I1-3)^3;
            F = sign_F*2*AA*abs(WT_k)/max(eps_k,1e-9);
        case 4
            % Compression-only EESM branch, matching forceExpression.m:
            % lam_ee = 1-eps (no tension branch), no clamps on lamr/beta,
            % c_AB directly fitted, F = A*2*WT/(lam_ee-1) (sign from
            % (lam_ee-1) itself, negative under compression).
            lam_ee  = 1 - eps_k;
            lam2_ee = 1/sqrt(lam_ee);
            I1_ee   = lam_ee^2 + 2*lam2_ee^2;
            I3_ee   = (lam_ee*lam2_ee*lam2_ee)^2;

            lamr = sqrt(I1_ee/(3*N_AB));
            beta = (3*lamr)/(1-lamr^3);
            w_iso = mu_AB*(N_AB*(beta*lamr+log(beta/sinh(beta)))-log(beta/lamr))+c_AB;
            w_aniso = (A1_AB/3)*(I1_ee-3)+(A2_AB/9)*(I1_ee-3)^2-(2*A1_AB/3)*log(I3_ee);
            WT_k = (1-f_AB)*w_iso + f_AB*w_aniso;

            F = AA*2*WT_k/(lam_ee-1);
        case 5
            WT_k = EE*( eps_k^2/2 + eps_k^3/6 + eps_k^3/(3*alpha_phen) );
            F = sign_F*2*AA*abs(WT_k)/max(eps_k,1e-9);
        case 6
            % Direct polynomial fit: F(lambda) is the polynomial itself,
            % no energy/Eq.28 conversion. lambda = 1-eps (compression
            % convention, matching how it was originally fit).
            lam_poly = 1 - eps_k;
            F = polyval(poly_coeffs, lam_poly);
            WT_k = NaN;
    end
end

%% ============================================================================
%  DEFAULT PARAMETERS
%% ============================================================================
function P = defaultParams()
    P = struct();
    P.unit_choice = 1; P.q = 3; P.unit_label = 'mm';
    P.scale_stl   = 1;
    P.stl_filename = '';
    P.use_hmax = false; P.Hmax_val = 0;
    P.wu = 3; P.fix_wu = 3;
    P.Force = -25; P.AA = 1e-4;
    P.hyper_choice = 4;
    P.mu_NH=0; P.C10=0; P.C01=0; P.C1=0; P.C2=0; P.C3=0;
    P.mu_AB=1.5e6; P.N_AB=9.5; P.A1_AB=1e6; P.A2_AB=1e6; P.c_AB=-6e5; P.f_AB=0.9;
    P.EE=0; P.alpha_phen=3; P.poly_degree=5; P.poly_coeffs=zeros(1,6);
    P.eps_sweep_max = 0.95; P.n_sweep = 2000;
    P.eps_star = NaN; P.E_t = NaN; P.hyper_label = '';
    P.C_GA=1; P.rho_ratio=0.5; P.n_GA=2; P.E_s = NaN; P.E_lat = NaN;
    P.nu_input = 0.3;
    P.do_disp = true; P.do_vm = true;
    P.sweepDone = false; P.gaDone = false; P.femDone = false;
end