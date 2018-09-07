function [res] = MUSCL_EulerRes2d_v4(q,~,dx,dy,N,M,~,fluxMethod)
%   A genuine 2d HLLE Riemnan solver for Euler Equations using a Monotonic
%   Upstreat Centered Scheme for Conservation Laws (MUSCL).
%  
%   e.g. where: limiter='MC'; fluxMethod='HLLE1d';
%
%   Flux at j+1/2
% 
%     j+1/2         Cell's grid:
%   | wL|   |
%   |  /|wR |           1   2   3   4        N-2 N-1  N
%   | / |\  |   {x=0} |-o-|-o-|-o-|-o-| ... |-o-|-o-|-o-| {x=L}
%   |/  | \ |             1   2   3   4        N-2 N-1  
%   |   |  \|
%   |   |   |       NC: Here cells 1 and N are ghost cells
%     j  j+1            faces 1 and N-1, are the real boundary faces.
%
%   q = cat(3, r, r.*u, r.*v, r.*E);
%   F = cat(3, r.*u, r.*u.^2+p, r.*u.*v, u.*(r.*E+p));
%   G = cat(3, r.*v, r.*u.*v, r.*v.^2+p, v.*(r.*E+p));
%
% Written by Manuel Diaz, NTU, 05.25.2015.
    res = zeros(M,N,4);

    % Normal unitary face vectors: (nx,ny)
    % normals = {[0,1], [1,0], [0,-1], [-1,0]}; % i.e.: [N, E, S, W] 

    % Build cells
    cell(M,N).all = M*N;
    for i = 1:M
        for j = 1:N
            cell(i,j).q = [q(i,j,1);q(i,j,2);q(i,j,3);q(i,j,4)];
            cell(i,j).res= zeros(4,1);
        end
    end
    
    % Build Faces
    face(M-1,N-1).all = (M-1)*(N-1);
    for i = 1:M-1
        for j = 1:N-1
            face(i,j).HLLE_x = zeros(4,1);
            face(i,j).HLLE_y = zeros(4,1);
            face(i,j).HLLE_c = zeros(4,1);
            face(i,j).flux_x = zeros(4,1);
            face(i,j).flux_y = zeros(4,1);
        end
    end
    
	%%%%%%%%%%%%%
    % Residuals %
    %%%%%%%%%%%%%
    
    % Compute fluxes across cells
    for i = 2:M-2     % all internal faces
        for j = 2:N-2 % all internal faces
            qSW = cell( i , j ).q;
            qSE = cell( i ,j+1).q;
            qNW = cell(i+1, j ).q;
            % compute HLLE1d flux
            face(i,j).HLLE_x = HLLE1Dflux(qSW,qSE,[1,0]);   % HLLE1d_{  i  ,j+1/2}
            face(i,j).HLLE_y = HLLE1Dflux(qSW,qNW,[0,1]);   % HLLE1d_{i+1/2,  j  }
        end
    end
    
    
    % Compute fluxes at the corners of cells (the stagered grid)
    for i = 2:M-2     % all internal faces
        for j = 2:N-2 % all internal faces
            qSW = cell( i , j ).q;
            qSE = cell( i ,j+1).q;
            qNW = cell(i+1, j ).q;
            qNE = cell(i+1,j+1).q;
            % compute HLLE2d flux
            face(i,j).HLLE_c = HLLE2Dflux(qSW,qSE,qNW,qNE); % HLLE2d_{i+1/2,j+1/2}
        end
    end

    
    % Assembling fluxes for HLLE2d with Simpsons Rule
    if strcmp(fluxMethod,'HLLE2d')
        for i = 2:M-1     % internal nodes
            for j = 2:N-1 % internal nodes
                face(i,j).flux_x = (HLLE_c(i,j) + 4*HLLE_x(i,j) + HLLE_c(i,j-1))/6; % F_{i,j+1/2}
                face(i,j).flux_y = (HLLE_c(i,j) + 4*HLLE_y(i,j) + HLLE_c(i-1,j))/6; % F_{i+1/2,j}
            end
        end
    end
    
    % contributions to the residual of cell (i,j) and cells around it
    for i = 2:M-2     % internal faces 
        for j = 2:N-2 % internal faces
            cell( i,j ).res = cell( i,j ).res + face(i,j).flux_x/dx;
            cell(i,j+1).res = cell(i,j+1).res - face(i,j).flux_x/dx;
            cell( i,j ).res = cell( i,j ).res + face(i,j).flux_y/dy;
            cell(i+1,j).res = cell(i+1,j).res - face(i,j).flux_y/dy;
        end
    end
    
    %%%%%%%%%%%
    % set BCs %
    %%%%%%%%%%%
    
    % Flux contribution of the MOST NORTH FACE: north face of cells j=M-1.
    for j = 2:N-2
        qL = cell(M-1,j).qS;     qR = qL;
        switch fluxMethod
            case 'HLLE1d', flux = HLLE1Dflux(qL,qR,[0,1]); % F_{i+1/2,j}
            case 'HLLE2d', flux = HLLE1Dflux(qL,qR,[0,1]); % F_{i+1/2,j}
        end
        cell(M-1,j).res = cell(M-1,j).res + flux/dy;
    end
    
    % Flux contribution of the MOST EAST FACE: east face of cell j=N-1.
    for i = 2:M-2
        qL = cell(i,N-1).qW;     qR = qL;
        switch fluxMethod
            case 'HLLE1d', flux = HLLE1Dflux(qL,qR,[1,0]); % F_{i,j+1/2}
            case 'HLLE2d', flux = HLLE1Dflux(qL,qR,[1,0]); % F_{i,j+1/2}
        end
        cell(i,N-1).res = cell(i,N-1).res + flux/dx;
    end
    
    % Flux contribution of the MOST SOUTH FACE: south face of cells j=2.
    for j = 2:N-2
        qR = cell(2,j).qN;     qL = qR;
        switch fluxMethod
            case 'HLLE1d', flux = HLLE1Dflux(qL,qR,[0,-1]); % F_{i-1/2,j}
            case 'HLLE2d', flux = HLLE1Dflux(qL,qR,[0,-1]); % F_{i-1/2,j}
        end
        cell(2,j).res = cell(2,j).res + flux/dy;
    end
    
    % Flux contribution of the MOST WEST FACE: west face of cells j=2.
    for i = 2:M-2
        qR = cell(i,2).qE;     qL = qR;
        switch fluxMethod
            case 'HLLE1d', flux = HLLE1Dflux(qL,qR,[-1,0]); % F_{i,j-1/2}
            case 'HLLE2d', flux = HLLE1Dflux(qL,qR,[-1,0]); % F_{i,j-1/2}
        end
        cell(i,2).res = cell(i,2).res + flux/dx;
    end
    
    % Prepare residual as layers: [rho, rho*u, rho*v, rho*E]
    parfor i = 2:M-1
        for j = 2:N-1
            res(i,j,:) = cell(i,j).res;
        end
    end
    
    % Debug
    % Q=[cell(:,:).res]; Q=reshape(Q(1,:),M,N); surf(Q);
end % 

%%%%%%%%%%%%%%%%%%%%%%%
% Auxiliary Functions %
%%%%%%%%%%%%%%%%%%%%%%%

function HLLE = HLLE1Dflux(qL,qR,normal)
    % Compute HLLE flux
    global gamma

    % normal vectors
    nx = normal(1);
    ny = normal(2);
       
    % Left state
    rL = qL(1);
    uL = qL(2)/rL;
    vL = qL(3)/rL;
    vnL = uL*nx+vL*ny;
    pL = (gamma-1)*( qL(4) - rL*(uL^2+vL^2)/2 );
    aL = sqrt(gamma*pL/rL);
    HL = ( qL(4) + pL ) / rL;
    
    % Right state
    rR = qR(1);
    uR = qR(2)/rR;
    vR = qR(3)/rR;
    vnR = uR*nx+vR*ny;
    pR = (gamma-1)*( qR(4) - rR*(uR^2+vR^2)/2 );
    aR = sqrt(gamma*pR/rR);
    HR = ( qR(4) + pR ) / rR;
    
    % First compute the Roe Averages
    RT = sqrt(rR/rL); % r = RT*rL;
    u = (uL+RT*uR)/(1+RT);
    v = (vL+RT*vR)/(1+RT);
    H = ( HL+RT* HR)/(1+RT);
    a = sqrt( (gamma-1)*(H-(u^2+v^2)/2) );
    vn = u*nx+v*ny;
    
    % Wave speed estimates
    SLm = min([ vnL-aL, vn-a, 0]);
    SRp = max([ vnR+aR, vn+a, 0]);
    
    % Left and Right fluxes
    FL=[rL*vnL; rL*vnL*uL + pL*nx; rL*vnL*vL + pL*ny; rL*vnL*HL];
    FR=[rR*vnR; rR*vnR*uR + pR*nx; rR*vnR*vR + pR*ny; rR*vnR*HR];
    
    % Compute the HLL flux.
    HLLE = ( SRp*FL - SLm*FR + SLm*SRp*(qR-qL) )/(SRp-SLm);
end

function HLLE = HLLE2Dflux(qSW,qSE,qNW,qNE)
    % Compute HLLE flux
    global gamma
    
    % West state
    rSW = qSW(1);
    uSW = qSW(2)/rSW;
    vSW = qSW(3)/rSW;
    pSW = (gamma-1)*( qSW(4) - rSW*(uSW^2+vSW^2)/2 );
    aSW = sqrt(gamma*pSW/rSW);
    HSW = ( qSW(4) + pSW ) / rSW;
    
    % East state
    rSE = qSE(1);
    uSE = qSE(2)/rSE;
    vSE = qSE(3)/rSE;
    pSE = (gamma-1)*( qSE(4) - rSE*(uSE^2+vSE^2)/2 );
    aSE = sqrt(gamma*pSE/rSE);
    HSE = ( qSE(4) + pSE ) / rSE;
    
    % South state
    rNW = qNW(1);
    uNW = qNW(2)/rNW;
    vNW = qNW(3)/rNW;
    pNW = (gamma-1)*( qNW(4) - rSW*(uNW^2+vNW^2)/2 );
    aNW = sqrt(gamma*pNW/rNW);
    HNW = ( qNW(4) + pNW ) / rNW;
    
    % North state
    rNE = qNE(1);
    uNE = qNE(2)/rNE;
    vNE = qNE(3)/rNE;
    pNE = (gamma-1)*( qNE(4) - rNE*(uNE^2+vNE^2)/2 );
    aNE = sqrt(gamma*pNE/rNE);
    HNE = ( qNE(4) + pNE ) / rNE;
    
    
    
    
    % Compute Roe Averages - SW to SE
    rSroe = sqrt(rSE/rSW); 
    uSroe = (uSW+rSroe*uSE)/(1+rSroe);
    vSroe = (vSW+rSroe*vSE)/(1+rSroe);
    HSroe = (HSW+rSroe*HSE)/(1+rSroe);
    aSroe = sqrt( (gamma-1)*(HSroe-0.5*(uSroe^2+vSroe^2)) );
    
    % Compute Roe Averages - NW to NE
    rNroe = sqrt(rNE/rNW); 
    uNroe = (uNW+rNroe*uNE)/(1+rNroe);
    vNroe = (vNW+rNroe*vNE)/(1+rNroe);
    HNroe = (HNW+rNroe*HNE)/(1+rNroe);
    aNroe = sqrt( (gamma-1)*(HNroe-0.5*(uNroe^2+vNroe^2)) );
    
    % Compute Roe Averages - SW to NW
    rWroe = sqrt(rSE/rSW); 
    uWroe = (uSW+rWroe*uSE)/(1+rWroe);
    vWroe = (vSW+rWroe*vSE)/(1+rWroe);
    HWroe = (HSW+rWroe*HSE)/(1+rWroe);
    aWroe = sqrt( (gamma-1)*(HWroe-0.5*(uWroe^2+vWroe^2)) );
    
    % Compute Roe Averages - SE to NE
    rEroe = sqrt(rNE/rSE); 
    uEroe = (uSE+rEroe*uNE)/(1+rEroe);
    vEroe = (vSE+rEroe*vNE)/(1+rEroe);
    HEroe = (HSE+rEroe*HNE)/(1+rEroe);
    aEroe = sqrt( (gamma-1)*(HEroe-0.5*(uEroe^2+vEroe^2)) );
    
    
    
    
    % Wave speed estimates in the S
    sSW = min([ uSW-aSW, uSW+aSW, uSroe-aSroe, uSroe+aSroe ]);
    sSE = max([ uSE-aSE, uSE+aSE, uSroe-aSroe, uSroe+aSroe ]);
    
    % Wave speed estimates in the N
    sNW = min([ uNW-aNW, uNW+aNW, uNroe-aNroe, uNroe+aNroe ]);
    sNE = max([ uNE-aNE, uNE+aNE, uNroe-aNroe, uNroe+aNroe ]);
    
    % Wave speed estimates in the W
    sWS = min([ uSW-aSW, uSW+aSW, uWroe-aWroe, uWroe+aWroe ]);
    sWN = max([ uNW-aNW, uNW+aNW, uWroe-aWroe, uWroe+aWroe ]);
    
    % Wave speed estimates in the E
    sES = min([ uSE-aSE, uSE+aSE, uEroe-aEroe, uEroe+aEroe ]);
    sEN = max([ uNE-aNE, uNE+aNE, uEroe-aEroe, uEroe+aEroe ]);
    
    % The maximum wave speed delimit the interacting region to a square domain
    sS  = min(sWS,sES); 
    sN  = max(sWN,sEN); 
    sW  = min(sSW,sNW); 
    sE  = max(sSE,sNE); 

    
    
    % Compute fluxes
    FL=[rL*vnL; rL*vnL*uL + pL*nx; rL*vnL*vL + pL*ny; rL*vnL*HL];
    FR=[rR*vnR; rR*vnR*uR + pR*nx; rR*vnR*vR + pR*ny; rR*vnR*HR];
    GL=[rL*vnL; rL*vnL*uL + pL*nx; rL*vnL*vL + pL*ny; rL*vnL*HL];
    GR=[rR*vnR; rR*vnR*uR + pR*nx; rR*vnR*vR + pR*ny; rR*vnR*HR];
    
    % Compute the HLL flux.
    HLLE = ( SRp*FL - SLm*FR + SLm*SRp*(qR-qL) )/(SRp-SLm);
    
end