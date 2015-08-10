function CeleST
try
    % Global try-catch on CeleST
    CSTMainWindow()
catch exception
    generateReport(exception)
end