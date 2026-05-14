local Api = {}
------------------ 基础类 ----------------
function Api.WebLoadOver(data)
    local backeTable = Api.Object:WebLoadOver(data)
    return backeTable
end

function Api.Login(data)
    local backeTable = Api.Object:Login(data)
    return backeTable
end

function Api.back(data)
    local backeTable = Api.Object:BackHome(data)
    return backeTable
end

function Api.Quit(data)
    local backeTable = Api.Object:Quit(data)
    return backeTable
end

function Api.addNullPlan(data)
    local backeTable = Api.Object:NullPlan(data)
    return backeTable
end

---------------- 模型上传模块 -------------------
function Api.WebLoadUp(data)
    local backeTable = Api.Object:WebUpLoad(data)
    return backeTable
end

function Api.LookModel(data)
    local backeTable = Api.Object:LookModel(data)
    return backeTable
end

------------------ 方案操作 -------------------
function Api.Load(data)
    local backeTable = Api.Object:OldLoadPlan(data)
    return backeTable
end

-- function Api.AnimationConfig(data)
--     local backeTable = Api.Object:AnimationConfig(data)
--     return backeTable
-- end

function Api.NewLoad(data)
    local backeTable = Api.Object:NewLoadPlan(data)
    return backeTable
end

function Api.Save(data)
    local backeTable = Api.Object:SavePlan(data)
    return backeTable
end

-- RegionInner：协作保存前校验（返回 { bSaveVS = false/true }）
function Api.ValidAssistorSave(data)
    local backeTable = Api.Object:ValidAssistorSave(data)
    return backeTable, true
end

-- RegionInner：以云端最新方案为基底，合并本地区域缓存并上传
-- 预期入参 data:
--   {
--       planName: string,
--       sandboxSchemeId: number,
--       userId: string,
--       eventName?: string  -- 可选，前端像素流回调事件名，默认 "RegionInnerSave"
--   }
function Api.RegionInnerMergeAndUpload(data)
    local backeTable = Api.Object:RegionInnerMergeAndUpload(data)
    return backeTable
end

function Api.SaveReturn(data)
    local backeTable = Api.Object:SaveReturn(data)
    return backeTable
end

function Api.AutoSave(data)
    local backeTable = Api.Object:AutoSave(data)
    return backeTable
end

------------------- Cad模块 -------------------
function Api.SetCadData(data)
    local backeTable = Api.Object:SetCadData(data)
    return backeTable
end

function Api.isCadData(data)
    local backeTable = Api.Object:IsCadData(data)
    return backeTable, true
end

function Api.IsCadData(data)
    local backeTable = Api.Object:IsCadData(data)
    return backeTable, true
end

function Api.IsShowCad(data)
    local backeTable = Api.Object:IsShowCad(data)
    return backeTable, true
end

function Api.GetCadData(data)
    local backeTable = Api.Object:GetCadData(data)
    return backeTable, true
end

function Api.CloseCadWindow(data)
    local backeTable = Api.Object:CloseCadWindow(data)
    return backeTable
end

function Api.StopUploadCAD(data)
    local backeTable = Api.Object:StopUploadCAD(data)
    return backeTable
end

-------------- 撤销
function Api.Undo(data)
    local backeTable = Api.Object:Undo(data)
    return backeTable
end

function Api.Redo(data)
    local backeTable = Api.Object:Redo(data)
    return backeTable
end

------------- 绘制
function Api.DrawPlace(data)
    local backeTable = Api.Object:DrawPlace(data)
    return backeTable
end

function Api.Mapping(data)
    local backeTable = Api.Object:Mapping(data)
    return backeTable
end

function Api.DeleteModel(data)
    local backeTable = Api.Object:DeleteModel(data)
    return backeTable
end

function Api.DrawModel(data)
    local backeTable = Api.Object:DrawModel(data)
    return backeTable
end

function Api.ModelInfo(data)
    local backeTable = Api.Object:ModelInfo(data)
    return backeTable, true
end

function Api.FloorInfo(data)
    local backeTable = Api.Object:FloorInfo(data)
    return backeTable, true
end

function Api.PipeInfo(data)
    local backeTable = Api.Object:PipeInfo(data)
    return backeTable, true
end

function Api.WallInfo(data)
    local backeTable = Api.Object:WallInfo(data)
    return backeTable, true
end

function Api.AreaInfo(data)
    local backeTable = Api.Object:AreaInfo(data)
    return backeTable, true
end

function Api.AddFloor(data)
    local backeTable = Api.Object:AddFloor(data)
    return backeTable
end

function Api.AreaAreaInfo(data)
    local backeTable = Api.Object:AreaAreaInfo(data)
    return backeTable, true
end

function Api.MessageInfo(data)
    local backeTable = Api.Object:MessageInfo(data)
    return backeTable, true
end

function Api.SSXInfo(data)
    local backeTable = Api.Object:SSXInfo(data)
    return backeTable, true
end

function Api.MaterialInfo(data)
    local backeTable = Api.Object:MaterialInfo(data)
    return backeTable, true
end

function Api.GroupInfo(data)
    local backeTable = Api.Object:GroupInfo(data)
    return backeTable, true
end

function Api.DrawDashedLine(data)
    local backeTable = Api.Object:DrawDashedLine(data)
    return backeTable, true
end

function Api.DashedLineInfo(data)
    local backeTable = Api.Object:DashedLineInfo(data)
    return backeTable, true
end

function Api.PassagewayInfo(data)
    local backeTable = Api.Object:PassagewayInfo(data)
    return backeTable, true
end

function Api.PathInfo(data)
    local backeTable = Api.Object:PathInfo(data)
    return backeTable, true
end

function Api.VeratcalLineInfo(data)
    local backeTable = Api.Object:VeratcalLineInfo(data)
    return backeTable, true
end

---------------- 视图
function Api.changeTo2D(data)
    local backeTable = Api.Object:changeTo2D(data)
    return backeTable
end

function Api.changeTo3D(data)
    local backeTable = Api.Object:changeTo3D(data)
    return backeTable
end

function Api.resetView(data)
    local backeTable = Api.Object:resetView(data)
    return backeTable
end

function Api.toBig(data)
    local backeTable = Api.Object:toBig(data)
    return backeTable
end

function Api.changeScale(data)
    local backeTable = Api.Object:changeScale(data)
    return backeTable
end

function Api.SilentDownload(data)
    local backeTable = Api.Object:SilentDownload(data)
    return backeTable, true
end

function Api.SelectModelMenu(data)
    local backeTable = Api.Object:SelectModelMenu(data)
    return backeTable
end

function Api.ClickModelMenu(data)
    local backeTable = Api.Object:ClickModelMenu(data)
    return backeTable
end

function Api.GroupTogether(data)
    local backeTable = Api.Object:GroupTogether(data)
    return backeTable
end

function Api.ModelArrayCopy(data)
    local backeTable = Api.Object:ModelArrayCopy(data)
    return backeTable
end

function Api.CancelModelArray(data)
    local backeTable = Api.Object:CancelModelArray(data)
    return backeTable
end

--- 导出
function Api.DownloadImg(data)
    local backeTable = Api.Object:DownloadImg(data)
    return backeTable
end

function Api.ExportPlantoCad(data)
    local backeTable = Api.Object:ExportPlantoCad(data)
    return backeTable
end

function Api.CancelExportCad(data)
    local backeTable = Api.Object:CancelExportCad(data)
    return backeTable
end

function Api.ClearSelect(data)
    local backeTable = Api.Object:ClearSelect(data)
    return backeTable
end

function Api.GroupSplit(data)
    local backeTable = Api.Object:GroupSplit(data)
    return backeTable
end

function Api.ChooseFacade(data)
    local backeTable = Api.Object:ChooseFacade(data)
    return backeTable
end

function Api.SetModleVisibility(data)
    local backeTable = Api.Object:SetModleVisibility(data)
    return backeTable
end

function Api.ShowVision(data)
    local backeTable = Api.Object:ShowVision(data)
    return backeTable
end

function Api.Copy(data)
    local backeTable = Api.Object:Copy(data)
    return backeTable
end

function Api.Paste(data)
    local backeTable = Api.Object:Paste(data)
    return backeTable
end

function Api.AdvancedCpopy(data)
    local backeTable = Api.Object:AdvancedCpopy(data)
    return backeTable
end

function Api.AdvancedPaste(data)
    local backeTable = Api.Object:AdvancedPaste(data)
    return backeTable
end

function Api.AnimationList(data)
    local backeTable = Api.Object:AnimationList(data)
    return backeTable, true
end

function Api.AnimationPlay(data)
    local backeTable = Api.Object:AnimationPlay(data)
    return backeTable
end

function Api.AnimationSinglePlay(data)
    local backeTable = Api.Object:AnimationSinglePlay(data)
    return backeTable
end

function Api.OpenLevel(data)
    local backeTable = Api.Object:OpenLevel(data)
    return backeTable
end

function Api.ActualEquipmentCondition(data)
    local backeTable = Api.Object:ActualEquipmentCondition(data)
    return backeTable
end

function Api.CreateWebTag(data)
    local backeTable = Api.Object:CreateWebTag(data)
    return backeTable
end

function Api.DeleteTag(data)
    local backeTable = Api.Object:DeleteTag(data)
    return backeTable
end

function Api.ClearTags(data)
    local backeTable = Api.Object:ClearTags(data)
    return backeTable
end

function Api.TransmitData(data)
    local backeTable = Api.Object:TransmitData(data)
    return backeTable
end

function Api.ToView(data)
    local backeTable = Api.Object:ToView(data)
    return backeTable
end

function Api.GoFangzhen(data)
    local backeTable = Api.Object:GoFangzhen(data)
    return backeTable
end

function Api.ModelTip(data)
    local backeTable = Api.Object:ModelTip(data)
    return backeTable
end

function Api.ModelTipHide(data)
    local backeTable = Api.Object:ModelTipHide(data)
    return backeTable
end

--- 自动保存
function Api.SaveUELocal(data)
    local backeTable = Api.Object:SaveUELocal(data)
    return backeTable
end

function Api.LoadUELocal(data)
    local backeTable = Api.Object:LoadUELocal(data)
    return backeTable, true
end

function Api.AutoSave(data)
    local backeTable = Api.Object:AutoSave(data)
    return backeTable
end

function Api.GetDrawing(data)
    local backeTable = Api.Object:GetDrawing(data)
    return backeTable
end

function Api.IsOpenPointCap(data)
    local backeTable = Api.Object:IsOpenPointCap(data)
    return backeTable, true
end

function Api.DisableKeyBoard(data)
    local backeTable = Api.Object:DisableKeyBoard(data)
    return backeTable
end

function Api.PageSearch(data)
    local backeTable = Api.Object:PageSearch(data)
    return backeTable, true
end

function Api.PageSize(data)
    local backeTable = Api.Object:PageSize(data)
    return backeTable, true
end

function Api.GetAutoSave(data)
    local backeTable = Api.Object:GetAutoSave(data)
    return backeTable, true
end

function Api.UseAutoSave(data)
    local backeTable = Api.Object:UseAutoSave(data)
    return backeTable
end

function Api.ClickSpace(data)
    local backeTable = Api.Object:ClickSpace(data)
    return backeTable
end

function Api.StopCrossCopy(data)
    local backeTable = Api.Object:StopCrossCopy(data)
    return backeTable
end

function Api.GetMapModel(data)
    local backeTable = Api.Object:GetMapModel(data)
    return backeTable, true
end

function Api.GenerateAnimation(data)
    local backeTable = Api.Object:GenerateAnimation(data)
    return backeTable
end

function Api.SelectPathAniList(data)
    local backeTable = Api.Object:SelectPathAniList(data)
    return backeTable
end

function Api.CloseLujinAni(data)
    local backeTable = Api.Object:CloseLujinAni(data)
    return backeTable
end

function Api.ClearSplineMenu(data)
    local backeTable = Api.Object:ClearSplineMenu(data)
    return backeTable
end

function Api.SynchronousToken(data)
    local backeTable = Api.Object:SynchronousToken(data)
    return backeTable, true
end

------------------ 绘制模式 -------------------
function Api.SwitchDrawMode(data)
    local backeTable = Api.Object:SwitchDrawMode(data)
    return backeTable
end

function Api.SwitchSchemeAssist(data)
    local backeTable = Api.Object:SwitchSchemeAssist(data)
    return backeTable
end

-- 设置当前方案是否为团队方案
-- data: { flag = true/false }
function Api.IsTeamScheme(data)
    local backeTable = Api.Object:IsTeamScheme(data)
    return backeTable
end

function Api.SelectRegion(data)
    local backeTable = Api.Object:SelectRegion(data)
    return backeTable
end

function Api.UpdateRegionData(data)
    local backeTable = Api.Object:UpdateRegionData(data)
    return backeTable
end

function Api.DeleteRegion(data)
    local backeTable = Api.Object:DeleteRegion(data)
    return backeTable
end

function Api.GetRegionData(data)
    local backeTable = Api.Object:GetRegionData(data)
    return backeTable
end

function Api.CommunicationCleanup(functionName)
    Api.Object:CommunicationCleanup(functionName)
end
function Api.IsCanAutoSave(data)
    Api.Object:IsCanAutoSave(data)
end

Api.object = nil

return Api
