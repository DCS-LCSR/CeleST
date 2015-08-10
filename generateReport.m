function generateReport(exception)

global filenames startTime fileLogID;

% Clean-up CeleST couldn't do, due to error
disp(['CeleST ending at ' datestr(clock)]);
diary off


% Get error report
errEncountered = getReport(exception, 'extended', 'hyperlinks', 'off');

% Error Reporting Window appears when error is caught
errWindow = figure('Name', 'Report Error', 'Menubar', 'none', 'Visible', 'off');
errMessage = uicontrol(errWindow, 'Style', 'edit', 'Units', 'Normalized', 'Position', [0.1 0.25 0.8 0.5]);
uicontrol(errWindow, 'Style', 'text', 'String', 'An error has occurred. Please type a brief message describing what you were doing prior to the error. Some useful information may include which window you were using or what was pressed prior to the error', 'Units', 'Normalized', 'Position', [0.05 0.8 0.9 0.15]);
uicontrol(errWindow, 'Style', 'pushbutton', 'String', 'Send Report', 'Units', 'Normalized', 'Position', [0.1 0.1 0.35 0.1], 'Callback', @SendReport);
uicontrol(errWindow, 'Style', 'pushbutton', 'String', 'Don''t Send', 'Units', 'Normalized', 'Position', [0.55 0.1 0.35 0.1], 'Callback', @DontSend);

set(errWindow, 'Visible', 'on');
waitfor(errWindow, 'BeingDeleted','on');

    function SendReport(hObject, eventdata)
        % Check for Blank Textbox
        if isempty(get(errMessage, 'String'))
            answer = questdlg('Are you sure you want to send the report with no body in the message?', 'Empty Body Encountered', 'Yes', 'No', 'No');
            if strcmp(answer,'No')
                return
            end
        end
        
        % Setup
        [sender,passphrase,recipients] = getEmailInfo();
        setpref('Internet','SMTP_Server','smtp.gmail.com');
        setpref('Internet','E_mail',sender);
        setpref('Internet','SMTP_Username',sender);
        setpref('Internet','SMTP_Password',passphrase);
        props = java.lang.System.getProperties;
        props.setProperty('mail.smtp.auth','true');
        props.setProperty('mail.smtp.socketFactory.class', 'javax.net.ssl.SSLSocketFactory');
        props.setProperty('mail.smtp.socketFactory.port','465');
        
        % Create Message
        message = ['Error Stack:' 10 errEncountered 10 10 'User message' 10 get(errMessage, 'String')];
        
        % Get Attachments
        attachments = {[filenames.log '/comWinLog'],fileLogID};
        
        % Send Mail
        sendmail(recipients,['CeleST Bug Report on ' startTime], message, attachments);
        close(errWindow);
    end
    function DontSend(hObject, eventdata)
        close(errWindow);
    end
    function [sender, passphrase, recipients] = getEmailInfo()
        configFID = fopen([filenames.curr '/bugreportinfo']);
        configInfo = textscan(configFID, '%s', 'delimiter', '\n');
        configInfo = configInfo{1};
        sender = configInfo{1};
        passphrase = configInfo{2};
        recipients = '';
        if length(configInfo) > 2
            recipients = configInfo(3:end);
        end
    end
end