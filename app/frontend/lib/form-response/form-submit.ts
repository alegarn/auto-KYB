export type FlashMessage = { type: 'alert' | 'notice'; message?: string } | null

type SubmitPayload = {
  data: Record<string, any>
  validate: boolean
  partial: boolean
  autosave?: boolean
}

type SubmitterDeps = {
  getForm: () => any
  path: string
  getBaseVersion: () => number | null
  getCurrentData: () => Record<string, any>
  getPartialData: () => Record<string, any>
  setFlashMessage: (message: FlashMessage) => void
  cancelAutosave: () => void
  onAutosaveSuccess: (fields: string[]) => void
}

export function createFormSubmitter(deps: SubmitterDeps) {
  const sendSave = (payload: SubmitPayload) => {
    deps.setFlashMessage(null)
    deps.cancelAutosave()

    const options = {
      preserveScroll: true,
      preserveState: true,
      only: payload.partial ? ['last_response', 'flash_message'] : [],
      onSuccess: () => {
        if (payload.partial) {
          deps.setFlashMessage({ type: 'notice', message: 'Form response saved successfully.' })
          if (payload.autosave) {
            deps.onAutosaveSuccess(Object.keys(payload.data))
          }
        }
      },
      onError: () => {
        deps.setFlashMessage({
          type: 'alert',
          message: 'Unable to submit the form right now. Please try again.'
        })
      }
    }

    const form = deps.getForm()
    form
      .transform(() => ({
        form_response: {
          data: payload.data,
          validate: payload.validate,
          partial: payload.partial,
          base_version: deps.getBaseVersion(),
        }
      }))
      .patch(deps.path, options)
  }

  const savePartial = async () => {
    const data = deps.getPartialData()
    if (Object.keys(data).length === 0) return
    sendSave({ data, validate: false, partial: true, autosave: true })
  }

  const submit = async (event: SubmitEvent) => {
    event.preventDefault()
    const submitter = event.submitter as HTMLButtonElement | null
    const validate = submitter?.value === 'true'
    const partial = !validate
    const data = partial ? deps.getPartialData() : deps.getCurrentData()

    if (partial && Object.keys(data).length === 0) {
      deps.setFlashMessage({ type: 'notice', message: 'No changes to save.' })
      return
    }

    sendSave({ data, validate, partial })
  }

  return { submit, savePartial }
}
