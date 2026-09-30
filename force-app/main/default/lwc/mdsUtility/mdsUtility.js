/**
 * @author Ruchira Patil
 * @desc This method used for Focus on modals for A11Y.
*/
export function focusFirstEle(cmp) {
	const focusableElements = 'lightning-combobox, lightning-button-icon, button, lightning-helptext, lightning-input, lightning-button,.row-focus, tr, a';
	const focusableElementsNotDisbaled = []; // Added this to exlcude disbaled focusable elements
	const modal = cmp.template.querySelector('.mds-modal, .mds-drawer');

	const firstFocusableElement = modal.querySelectorAll(focusableElements)[0];
	const focusableContent = modal.querySelectorAll(focusableElements);
	for(let i=0; i< focusableContent.length; i++){
		if(focusableContent[i].disabled === false){
			focusableElementsNotDisbaled.push(focusableContent[i]); // Pushing only non disabled focusable elements 
		}
		
		if(focusableContent[i].tagName.toLowerCase() === 'a'){
			focusableElementsNotDisbaled.push(focusableContent[i]);
		}
		
	}
	const lastFocusableElement = focusableElementsNotDisbaled[focusableElementsNotDisbaled.length - 1]; // Modified this based on dynamically retrieved non disabled focusable Elements
	firstFocusableElement.focus();
	cmp.template.addEventListener('keydown', function (event) {
		let isTabPressed = event.key === 'Tab' || event.keyCode === 9;
		if (!isTabPressed) {
			return;
		}
		if (event.shiftKey) {
			if (cmp.template.activeElement === firstFocusableElement) {
				lastFocusableElement.focus();
				event.stopPropagation()
				event.preventDefault();
			}
		} else {
			if (cmp.template.activeElement === lastFocusableElement) {
				firstFocusableElement.focus();
				event.preventDefault();
				event.stopPropagation()
			}
		}
	});
}